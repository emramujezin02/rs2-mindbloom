using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Security.DTOs;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using MindBloom.Infrastructure.Services;
using MindBloom.Messaging.Contracts.Notifications;
using Moq;

namespace MindBloom.UnitTests.Authentication;

// No application host/startup, configuration files, SQL, Docker, Stripe or
// outbound HTTP. Real JWT issuance and JwtBearer authentication, InMemory only.
public sealed class AccessTokenSessionRevocationTests
{
    [Fact]
    public async Task Login_issues_matching_session_and_signed_access_token()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        var row = Assert.Single(await f.Db.RefreshTokens.ToListAsync());
        Assert.Equal(row.SessionId, Sid(pair.Token));
        Assert.True(await f.AuthenticateAsync(pair.Token));
        Assert.Equal(f.User.Id, pair.Id);
        Assert.Equal("Client", pair.Role);
    }

    [Fact]
    public async Task Logout_rejects_access_and_refresh_but_preserves_independent_session()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var other = await f.LoginAsync();
        Assert.NotEqual(Sid(first.Token), Sid(other.Token));
        Assert.True(await f.AuthenticateAsync(first.Token));
        await f.Service.LogoutAsync(f.User.Id, first.RefreshToken);
        Assert.False(await f.AuthenticateAsync(first.Token));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(first.RefreshToken));
        Assert.True(await f.AuthenticateAsync(other.Token));
        Assert.NotEmpty((await f.RefreshAsync(other.RefreshToken)).Token);
    }

    [Fact]
    public async Task Rotation_keeps_session_then_logout_revokes_both_access_tokens()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var rotated = await f.RefreshAsync(first.RefreshToken);
        Assert.Equal(Sid(first.Token), Sid(rotated.Token));
        Assert.NotEqual(first.RefreshToken, rotated.RefreshToken);
        Assert.True(await f.AuthenticateAsync(first.Token));
        Assert.True(await f.AuthenticateAsync(rotated.Token));
        var rows = await f.Db.RefreshTokens.ToListAsync();
        Assert.Equal(2, rows.Count);
        Assert.Single(rows, row => row.RevokedAtUtc == null);
        await f.Service.LogoutAsync(f.User.Id, rotated.RefreshToken);
        Assert.False(await f.AuthenticateAsync(first.Token));
        Assert.False(await f.AuthenticateAsync(rotated.Token));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(rotated.RefreshToken));
    }

    [Fact]
    public async Task Logout_with_rotated_predecessor_still_revokes_live_successor()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var next = await f.RefreshAsync(first.RefreshToken);
        await f.Service.LogoutAsync(f.User.Id, first.RefreshToken);
        await f.Service.LogoutAsync(f.User.Id, first.RefreshToken);
        Assert.False(await f.AuthenticateAsync(next.Token));
        Assert.All(await f.Db.RefreshTokens.ToListAsync(), row => Assert.NotNull(row.RevokedAtUtc));
    }

    [Fact]
    public async Task Reused_refresh_revokes_session_without_revoking_other_sessions()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var other = await f.LoginAsync();
        var rotated = await f.RefreshAsync(first.RefreshToken);
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(first.RefreshToken));
        Assert.False(await f.AuthenticateAsync(rotated.Token));
        Assert.True(await f.AuthenticateAsync(other.Token));
    }

    [Fact]
    public async Task Logout_all_revokes_all_existing_sessions()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var second = await f.LoginAsync();
        await f.Service.LogoutAllAsync(f.User.Id);
        Assert.False(await f.AuthenticateAsync(first.Token));
        Assert.False(await f.AuthenticateAsync(second.Token));
    }

    [Fact]
    public async Task Expired_session_rejects_access_and_refresh()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        var row = await f.Db.RefreshTokens.SingleAsync();
        row.ExpiresAtUtc = DateTime.UtcNow.AddSeconds(-1);
        await f.Db.SaveChangesAsync();
        Assert.False(await f.AuthenticateAsync(pair.Token));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(pair.RefreshToken));
        Assert.NotNull(row.RevokedAtUtc);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("not-a-session")]
    [InlineData("00000000-0000-0000-0000-000000000001")]
    public async Task Missing_or_malformed_sid_is_rejected(string? sid)
    {
        await using var f = await Fixture.CreateAsync();
        await f.LoginAsync();
        Assert.False(await f.AuthenticateAsync(f.CraftToken(sid)));
    }

    [Fact]
    public async Task Unknown_session_is_rejected()
    {
        await using var f = await Fixture.CreateAsync();
        await f.LoginAsync();
        Assert.False(await f.AuthenticateAsync(f.CraftToken(Guid.NewGuid().ToString("N"))));
    }

    [Theory]
    [InlineData("raw")]
    [InlineData("mapped")]
    [InlineData("conflicting-user")]
    public async Task Duplicate_sid_or_conflicting_subject_is_rejected(string kind)
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        var extra = kind == "conflicting-user"
            ? new Claim(ClaimTypes.NameIdentifier, "999")
            : new Claim(kind == "raw" ? "sid" : ClaimTypes.Sid, Sid(pair.Token));
        Assert.False(await f.AuthenticateAsync(f.CraftToken(Sid(pair.Token), extra: extra)));
    }

    [Theory]
    [InlineData("expired-jwt")]
    [InlineData("wrong-signature")]
    [InlineData("wrong-audience")]
    [InlineData("wrong-issuer")]
    public async Task Jwt_cryptographic_and_lifetime_validation_is_preserved(string defect)
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        Assert.False(await f.AuthenticateAsync(f.CraftToken(Sid(pair.Token), defect)));
    }

    [Theory]
    [InlineData("blocked")]
    [InlineData("inactive")]
    [InlineData("deleted-session")]
    [InlineData("future-session")]
    public async Task User_and_session_guards_are_preserved(string state)
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        if (state == "blocked") f.User.IsBlocked = true;
        if (state == "inactive") f.User.IsActive = false;
        var row = await f.Db.RefreshTokens.SingleAsync();
        if (state == "deleted-session") row.IsDeleted = true;
        if (state == "future-session") row.IssuedAtUtc = DateTime.UtcNow.AddHours(1);
        await f.Db.SaveChangesAsync();
        Assert.False(await f.AuthenticateAsync(pair.Token));
    }

    [Fact]
    public async Task Logout_cannot_revoke_another_users_session()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        await f.Service.LogoutAsync(999, pair.RefreshToken);
        Assert.True(await f.AuthenticateAsync(pair.Token));
    }

    [Fact]
    public async Task Malformed_stored_refresh_session_is_not_rotated()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        (await f.Db.RefreshTokens.SingleAsync()).SessionId = "";
        await f.Db.SaveChangesAsync();
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(pair.RefreshToken));
        Assert.Equal(1, await f.Db.RefreshTokens.CountAsync());
    }

    [Fact]
    public async Task Token_issuer_requires_session_identifier()
    {
        await using var f = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<ArgumentException>(() => f.Issuer.GenerateTokenAsync(f.User, ""));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Post_commit_audit_failure_never_reactivates_logout_session(bool all)
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var other = await f.LoginAsync();
        f.Audit.Setup(x => x.WriteAsync(It.IsAny<SecurityAuditWriteDto>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new IOException("synthetic audit failure"));
        await Assert.ThrowsAsync<AuthSessionAuditException>(() => all
            ? f.Service.LogoutAllAsync(f.User.Id)
            : f.Service.LogoutAsync(f.User.Id, first.RefreshToken));
        Assert.False(await f.AuthenticateAsync(first.Token));
        Assert.Equal(!all, await f.AuthenticateAsync(other.Token));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(first.RefreshToken));
    }

    [Fact]
    public async Task Password_change_revokes_all_sessions_even_when_success_audit_fails()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var other = await f.LoginAsync();
        f.Audit.Setup(x => x.WriteAsync(It.IsAny<SecurityAuditWriteDto>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new IOException("synthetic audit failure"));
        await Assert.ThrowsAsync<AuthSessionAuditException>(() => f.Service.ChangePasswordAsync(f.User.Id,
            new ChangePasswordDto { CurrentPassword = "synthetic-old", NewPassword = "Synthetic-New1!", ConfirmNewPassword = "Synthetic-New1!" }));
        Assert.False(await f.AuthenticateAsync(first.Token));
        Assert.False(await f.AuthenticateAsync(other.Token));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(first.RefreshToken));
    }

    [Fact]
    public async Task Invalid_current_password_preserves_sessions_and_audits_failure()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        f.RejectPasswordChecks();
        await Assert.ThrowsAsync<MindBloom.Application.Common.Exceptions.BadRequestException>(() =>
            f.Service.ChangePasswordAsync(f.User.Id, new ChangePasswordDto {
                CurrentPassword = "wrong", NewPassword = "Synthetic-New1!", ConfirmNewPassword = "Synthetic-New1!" }));
        Assert.True(await f.AuthenticateAsync(pair.Token));
        f.Audit.Verify(x => x.WriteAsync(It.Is<SecurityAuditWriteDto>(row =>
            row.EventType == "PasswordChangeFailed" && !row.IsSuccessful), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Password_reset_consumes_code_and_revokes_all_refresh_sessions()
    {
        await using var f = await Fixture.CreateAsync();
        var first = await f.LoginAsync();
        var second = await f.LoginAsync();
        var encoded = Microsoft.AspNetCore.WebUtilities.WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes("synthetic-identity-token"));
        f.Db.PasswordResetCodes.Add(new PasswordResetCode { Email = f.User.Email!,
            TokenHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(encoded))),
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(5) });
        await f.Db.SaveChangesAsync();
        await f.Service.ResetPasswordAsync(new ResetPasswordDto { Email = f.User.Email!, Token = encoded, NewPassword = "Synthetic-New1!" });
        Assert.True((await f.Db.PasswordResetCodes.SingleAsync()).IsUsed);
        Assert.False(await f.AuthenticateAsync(first.Token));
        Assert.False(await f.AuthenticateAsync(second.Token));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(first.RefreshToken));
    }

    [Fact]
    public async Task Stale_tracked_refresh_cannot_resurrect_externally_revoked_session()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        await f.RevokeFromOtherContextAsync();
        Assert.Null((await f.Db.RefreshTokens.SingleAsync()).RevokedAtUtc); // intentionally stale tracker
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => f.RefreshAsync(pair.RefreshToken));
        Assert.False(await f.AuthenticateAsync(pair.Token));
        Assert.Equal(1, await f.Db.RefreshTokens.CountAsync());
    }
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Account_deletion_revokes_sessions_before_its_audit(bool auditFails)
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        if (auditFails) f.Audit.Setup(x => x.WriteAsync(It.IsAny<SecurityAuditWriteDto>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new IOException("synthetic audit failure"));
        var task = f.Service.DeleteAccountAsync(f.User.Id, new DeleteAccountRequestDto { Password = "synthetic-password" });
        if (auditFails) await Assert.ThrowsAsync<IOException>(() => task);
        else await task;
        Assert.False(f.User.IsActive);
        Assert.True(f.User.IsBlocked);
        Assert.False(await f.AuthenticateAsync(pair.Token));
        Assert.All(await f.Db.RefreshTokens.ToListAsync(), row => Assert.NotNull(row.RevokedAtUtc));
    }
    [Fact]
    public async Task Rejected_password_policy_preserves_sessions_and_failed_audit()
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        f.RejectChangePolicy();
        await Assert.ThrowsAsync<MindBloom.Application.Common.Exceptions.BadRequestException>(() => f.Service.ChangePasswordAsync(f.User.Id,
            new ChangePasswordDto { CurrentPassword = "synthetic-old", NewPassword = "Synthetic-New1!", ConfirmNewPassword = "Synthetic-New1!" }));
        Assert.True(await f.AuthenticateAsync(pair.Token));
        f.Audit.Verify(x => x.WriteAsync(It.Is<SecurityAuditWriteDto>(row => row.EventType == "PasswordChangeFailed" &&
            row.FailureReason == "IdentityPasswordPolicyRejected"), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("expired")]
    [InlineData("tampered")]
    [InlineData("policy")]
    public async Task Invalid_password_reset_cannot_consume_code_or_revoke_sessions(string failure)
    {
        await using var f = await Fixture.CreateAsync();
        var pair = await f.LoginAsync();
        var encoded = Microsoft.AspNetCore.WebUtilities.WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes("synthetic-identity-token"));
        f.Db.PasswordResetCodes.Add(new PasswordResetCode { Email = f.User.Email!,
            TokenHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(encoded))),
            ExpiresAtUtc = failure == "expired" ? DateTime.UtcNow.AddMinutes(-1) : DateTime.UtcNow.AddMinutes(5) });
        await f.Db.SaveChangesAsync();
        if (failure == "policy") f.RejectResetPolicy();
        await Assert.ThrowsAsync<MindBloom.Application.Common.Exceptions.BadRequestException>(() => f.Service.ResetPasswordAsync(new ResetPasswordDto {
            Email = f.User.Email!, Token = failure == "tampered" ? "tampered" : encoded, NewPassword = "Synthetic-New1!" }));
        Assert.False((await f.Db.PasswordResetCodes.SingleAsync()).IsUsed);
        Assert.True(await f.AuthenticateAsync(pair.Token));
        Assert.Null((await f.Db.RefreshTokens.SingleAsync()).RevokedAtUtc);
    }
    private static string Sid(string token) => new JwtSecurityTokenHandler().ReadJwtToken(token).Claims.Single(c => c.Type == "sid").Value;

    private sealed class Fixture : IAsyncDisposable
    {
        // Synthetic test signing material, never loaded from real configuration.
        private const string SigningKey = "synthetic-unit-only-signing-material-00000000000000000000000000000000";
        private readonly ServiceProvider _services;
        private readonly Mock<UserManager<ApplicationUser>> _users;
        public ApplicationDbContext Db { get; }
        public ApplicationUser User { get; }
        public AuthService Service { get; }
        public Mock<ISecurityAuditService> Audit { get; } = new(MockBehavior.Strict);
        private readonly DbContextOptions<ApplicationDbContext> _options;
        public JwtTokenService Issuer { get; }

        private Fixture()
        {
            _options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase($"logout-unit-{Guid.NewGuid():N}").Options;
            Db = new ApplicationDbContext(_options);
            User = new ApplicationUser { Id = 72, UserName = "session@example.test", Email = "session@example.test",
                FirstName = "Synthetic", LastName = "Session", IsActive = true, IsEmailVerified = true };
            _users = new Mock<UserManager<ApplicationUser>>(Mock.Of<IUserStore<ApplicationUser>>(), null!, null!, null!, null!, null!, null!, null!, null!);
            _users.Setup(x => x.FindByEmailAsync(User.Email!)).ReturnsAsync(User);
            _users.Setup(x => x.FindByIdAsync(User.Id.ToString())).ReturnsAsync(User);
            _users.SetupGet(x => x.Users).Returns(Db.Users);
            _users.Setup(x => x.ChangePasswordAsync(User, It.IsAny<string>(), It.IsAny<string>())).ReturnsAsync(IdentityResult.Success);
            _users.Setup(x => x.ResetPasswordAsync(User, It.IsAny<string>(), It.IsAny<string>())).ReturnsAsync(IdentityResult.Success);
            _users.Setup(x => x.CheckPasswordAsync(User, It.IsAny<string>())).ReturnsAsync(true);
            _users.Setup(x => x.IsLockedOutAsync(User)).ReturnsAsync(false);
            _users.Setup(x => x.ResetAccessFailedCountAsync(User)).ReturnsAsync(IdentityResult.Success);
            _users.Setup(x => x.GetRolesAsync(User)).ReturnsAsync(new List<string> { "Client" });
            Issuer = new JwtTokenService(Options.Create(new JwtSettings { SecretKey = SigningKey,
                Issuer = "synthetic-issuer", Audience = "synthetic-audience", ExpirationInMinutes = 15 }), _users.Object);
            var audit = Audit;
            audit.Setup(x => x.WriteAsync(It.IsAny<SecurityAuditWriteDto>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            Service = new AuthService(_users.Object, Db, Issuer,
                new Mock<ITherapistService>(MockBehavior.Strict).Object,
                new Mock<INotificationPublisher>(MockBehavior.Strict).Object, audit.Object);
            var services = new ServiceCollection();
            services.AddLogging();
            services.AddSingleton(Db);
            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters {
                    ValidateIssuer = true, ValidIssuer = "synthetic-issuer", ValidateAudience = true,
                    ValidAudience = "synthetic-audience", ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(SigningKey)),
                    ValidateLifetime = true, ClockSkew = TimeSpan.Zero };
                options.Events = new JwtBearerEvents { OnTokenValidated = AccessTokenSessionValidator.ValidateAsync };
            });
            _services = services.BuildServiceProvider();
        }

        public static async Task<Fixture> CreateAsync()
        {
            var f = new Fixture(); f.Db.Users.Add(f.User); await f.Db.SaveChangesAsync(); return f;
        }
        public void RejectChangePolicy() => _users.Setup(x => x.ChangePasswordAsync(User, It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "synthetic policy rejection" }));
        public void RejectResetPolicy() => _users.Setup(x => x.ResetPasswordAsync(User, It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "synthetic policy rejection" }));
        public void RejectPasswordChecks() => _users.Setup(x => x.CheckPasswordAsync(User, It.IsAny<string>())).ReturnsAsync(false);
        public async Task RevokeFromOtherContextAsync()
        {
            await using var other = new ApplicationDbContext(_options);
            foreach (var row in await other.RefreshTokens.Where(row => row.UserId == User.Id).ToListAsync())
                row.RevokedAtUtc = DateTime.UtcNow;
            await other.SaveChangesAsync();
        }
        public Task<AuthResponseDto> LoginAsync() => Service.LoginAsync(new LoginRequestDto {
            Email = User.Email!, Password = "synthetic-password" });
        public Task<AuthResponseDto> RefreshAsync(string token) => Service.RefreshTokenAsync(new RefreshTokenRequestDto { RefreshToken = token });
        public async Task<bool> AuthenticateAsync(string token)
        {
            using var scope = _services.CreateScope();
            var http = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
            http.Request.Headers.Authorization = $"Bearer {token}";
            return (await http.AuthenticateAsync(JwtBearerDefaults.AuthenticationScheme)).Succeeded;
        }
        public string CraftToken(string? sid, string defect = "", Claim? extra = null)
        {
            var claims = new List<Claim> { new(JwtRegisteredClaimNames.Sub, User.Id.ToString()), new(ClaimTypes.Role, "Client") };
            if (sid != null) claims.Add(new Claim("sid", sid));
            if (extra != null) claims.Add(extra);
            var now = DateTime.UtcNow;
            return new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(
                issuer: defect == "wrong-issuer" ? "other" : "synthetic-issuer",
                audience: defect == "wrong-audience" ? "other" : "synthetic-audience", claims: claims,
                notBefore: now.AddHours(-1), expires: defect == "expired-jwt" ? now.AddMinutes(-1) : now.AddMinutes(15),
                signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(
                    defect == "wrong-signature" ? new string('x', 64) : SigningKey)), SecurityAlgorithms.HmacSha256)));
        }
        public async ValueTask DisposeAsync()
        {
            _users.Object.Dispose(); await _services.DisposeAsync(); await Db.DisposeAsync();
        }
    }
}
