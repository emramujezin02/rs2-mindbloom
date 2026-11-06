using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Messaging.Contracts.Notifications;
using Moq;
using Moq.Protected;
using System.Text.RegularExpressions;

namespace MindBloom.UnitTests.Authentication;

// Real AuthService and audit mapping, isolated InMemory storage, mocked Identity
// credential checks/JWT issuance and an in-process email capture. No host/config,
// SQL, Docker, sockets or real email. These tests do not prove SQL concurrency.
public sealed class AuthTwoFactorEntryTests
{
    [Theory]
    [InlineData("entry@example.test", "Client")]
    [InlineData("client@mindbloom.ba", "Client")]
    [InlineData("admin@mindbloom.ba", "Admin")]
    public async Task StandardLogin_WithTwoFactorEnabled_DeniesBeforeAnyAuthIssuance(string email, string role)
    {
        await using var fixture = await Fixture.CreateAsync(email: email, role: role);

        var error = await Assert.ThrowsAsync<UnauthorizedException>(() =>
            fixture.Service.LoginAsync(fixture.Request()));

        Assert.Equal("Two-factor authentication is required. Use the two-factor login flow.", error.Message);
        fixture.Users.Verify(manager => manager.CheckPasswordAsync(fixture.User, "synthetic-password"), Times.Once);
        await fixture.AssertNoAuthPairAsync();
        Assert.Empty(await fixture.Db.TwoFactorLoginChallenges.ToListAsync());
        Assert.Empty(fixture.Emails);
    }

    [Theory]
    [InlineData(false, false, false)]
    [InlineData(false, false, true)]
    [InlineData(false, true, false)]
    [InlineData(false, true, true)]
    [InlineData(true, false, false)]
    [InlineData(true, false, true)]
    [InlineData(true, true, false)]
    [InlineData(true, true, true)]
    public async Task Entry_WithTwoFactorDisabled_PreservesAuthPairAndRememberMe(bool twoFactorEntry, bool rememberMe, bool demo)
    {
        await using var fixture = await Fixture.CreateAsync(twoFactor: false,
            email: demo ? "client@mindbloom.ba" : "entry@example.test");
        var request = fixture.Request(rememberMe);
        AuthResponseDto response;
        if (twoFactorEntry)
        {
            var envelope = await fixture.Service.LoginWith2FAAsync(request);
            Assert.False(envelope.RequiresTwoFactor);
            Assert.Null(envelope.ChallengeToken);
            Assert.Null(envelope.ChallengeExpiresAtUtc);
            response = Assert.IsType<AuthResponseDto>(envelope.Auth);
        }
        else response = await fixture.Service.LoginAsync(request);

        await fixture.AssertAuthPairAsync(response, rememberMe);
        Assert.Empty(await fixture.Db.TwoFactorLoginChallenges.ToListAsync());
        Assert.Empty(fixture.Emails);
    }

    [Theory]
    [InlineData("entry@example.test", "Client")]
    [InlineData("client@mindbloom.ba", "Client")]
    [InlineData("admin@mindbloom.ba", "Admin")]
    public async Task TwoFactorEntry_WithTwoFactorEnabled_IssuesOnlyChallengeIncludingDemo(string email, string role)
    {
        await using var fixture = await Fixture.CreateAsync(email: email, role: role);

        var response = await fixture.Service.LoginWith2FAAsync(fixture.Request(rememberMe: true));

        Assert.True(response.RequiresTwoFactor);
        Assert.Null(response.Auth);
        Assert.False(string.IsNullOrWhiteSpace(response.ChallengeToken));
        await fixture.AssertNoAuthPairAsync();
        var challenge = Assert.Single(await fixture.Db.TwoFactorLoginChallenges.AsNoTracking().ToListAsync());
        Assert.Equal(fixture.User.Id, challenge.UserId);
        Assert.NotEqual(response.ChallengeToken, challenge.ChallengeHash);
        Assert.False(challenge.IsUsed);
        Assert.True(challenge.RememberMe);
        Assert.Equal(5, challenge.MaximumAttempts);
        Assert.Equal(TimeSpan.FromMinutes(5), challenge.ExpiresAtUtc - challenge.IssuedAtUtc);
        Assert.Equal(challenge.ExpiresAtUtc, response.ChallengeExpiresAtUtc);
        var emailMessage = Assert.Single(fixture.Emails);
        Assert.Equal(email, emailMessage.RecipientEmail);
        Assert.Equal(NotificationEventType.TwoFactorCodeRequested, emailMessage.EventType);
        Assert.Contains(await fixture.Db.SecurityAuditLogs.ToListAsync(), audit =>
            audit.EventType == "TwoFactorChallengeIssued" && audit.IsSuccessful);
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task WrongPassword_PreservesGenericDenialBeforeTwoFactorDisclosure(bool twoFactorEntry, bool twoFactor)
    {
        await using var fixture = await Fixture.CreateAsync(twoFactor: twoFactor);
        fixture.PasswordValid = false;

        var error = await Assert.ThrowsAsync<UnauthorizedException>(() => fixture.EnterAsync(twoFactorEntry));

        Assert.Equal("Invalid credentials.", error.Message);
        fixture.Users.Verify(manager => manager.AccessFailedAsync(fixture.User), Times.Once);
        Assert.Equal(1, fixture.User.AccessFailedCount);
        await fixture.AssertNoAuthPairAsync();
        Assert.Empty(await fixture.Db.TwoFactorLoginChallenges.ToListAsync());
        Assert.Empty(fixture.Emails);
        var audit = Assert.Single(await fixture.Db.SecurityAuditLogs.ToListAsync());
        Assert.Equal("LoginFailed", audit.EventType);
        Assert.Equal("InvalidCredentials", audit.FailureReason);
        Assert.False(audit.IsSuccessful);
    }

    [Theory]
    [InlineData(false, "blocked")]
    [InlineData(true, "blocked")]
    [InlineData(false, "inactive")]
    [InlineData(true, "inactive")]
    [InlineData(false, "lockout")]
    [InlineData(true, "lockout")]
    [InlineData(false, "email")]
    [InlineData(true, "email")]
    public async Task UnavailableAccount_IsRejectedBeforeCredentialOrAuthIssuance(bool twoFactorEntry, string reason)
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.User.IsBlocked = reason == "blocked";
        fixture.User.IsActive = reason != "inactive";
        fixture.User.IsEmailVerified = reason != "email";
        fixture.LockedOut = reason == "lockout";

        var error = await Assert.ThrowsAsync<UnauthorizedException>(() => fixture.EnterAsync(twoFactorEntry));

        Assert.Equal(reason == "email" ? "Email is not verified." : "Invalid credentials.", error.Message);
        fixture.Users.Verify(manager => manager.CheckPasswordAsync(It.IsAny<ApplicationUser>(), It.IsAny<string>()), Times.Never);
        await fixture.AssertNoAuthPairAsync();
        Assert.Empty(await fixture.Db.TwoFactorLoginChallenges.ToListAsync());
        Assert.Empty(fixture.Emails);
        Assert.False(Assert.Single(await fixture.Db.SecurityAuditLogs.ToListAsync()).IsSuccessful);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task WrongPassword_StillRecordsThresholdLockout(bool twoFactorEntry)
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.PasswordValid = false;
        fixture.LockOnPasswordFailure = true;

        var error = await Assert.ThrowsAsync<UnauthorizedException>(() => fixture.EnterAsync(twoFactorEntry));

        Assert.Equal("Invalid credentials.", error.Message);
        fixture.Users.Verify(manager => manager.AccessFailedAsync(fixture.User), Times.Once);
        Assert.True(fixture.LockedOut);
        var audit = Assert.Single(await fixture.Db.SecurityAuditLogs.ToListAsync());
        Assert.Equal("AccountTemporarilyLocked", audit.EventType);
        Assert.Equal("MaximumFailedLoginAttemptsExceeded", audit.FailureReason);
        await fixture.AssertNoAuthPairAsync();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task VerifyTwoFactor_RealChallengeFlowStillIssuesAuthPairAndRejectsSequentialReplay(bool rememberMe)
    {
        await using var fixture = await Fixture.CreateAsync();
        var challenge = await fixture.Service.LoginWith2FAAsync(fixture.Request(rememberMe));
        await fixture.AssertNoAuthPairAsync();
        // Read only the synthetic message captured by this fixture, never a real mailbox.
        var code = Regex.Match(Assert.IsType<string>(Assert.Single(fixture.Emails).Body), @"\b\d{6}\b");
        Assert.True(code.Success);
        var request = new Verify2FADto { ChallengeToken = challenge.ChallengeToken!, Code = code.Value };

        var response = await fixture.Service.Verify2FAAsync(request);

        await fixture.AssertAuthPairAsync(response, rememberMe);
        var saved = Assert.Single(await fixture.Db.TwoFactorLoginChallenges.AsNoTracking().ToListAsync());
        Assert.True(saved.IsUsed);
        Assert.NotNull(saved.UsedAtUtc);
        Assert.Contains(await fixture.Db.SecurityAuditLogs.ToListAsync(), audit =>
            audit.EventType == "TwoFactorVerificationSucceeded" && audit.IsSuccessful);
        await Assert.ThrowsAsync<UnauthorizedException>(() => fixture.Service.Verify2FAAsync(request));
        fixture.Jwt.Verify(issuer => issuer.GenerateTokenAsync(fixture.User), Times.Once);
        fixture.Jwt.Verify(issuer => issuer.GenerateRefreshToken(), Times.Once);
        Assert.Single(await fixture.Db.RefreshTokens.ToListAsync());
    }

    private sealed class Fixture : IAsyncDisposable
    {
        public ApplicationDbContext Db { get; }
        public ApplicationUser User { get; }
        public Mock<UserManager<ApplicationUser>> Users { get; }
        public Mock<IJwtTokenService> Jwt { get; } = new(MockBehavior.Strict);
        public List<EmailNotificationMessage> Emails { get; } = [];
        public AuthService Service { get; }
        public string Role { get; }
        public bool PasswordValid { get; set; } = true;
        public bool LockedOut { get; set; }
        public bool LockOnPasswordFailure { get; set; }

        private Fixture(bool twoFactor, string email, string role)
        {
            Role = role;
            Db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase($"two-factor-entry-{Guid.NewGuid():N}").Options);
            User = new ApplicationUser
            {
                Id = 71, FirstName = "Synthetic", LastName = "Entry", UserName = email,
                Email = email, IsActive = true, IsEmailVerified = true,
                TwoFactorEnabledCustom = twoFactor
            };
            Users = new Mock<UserManager<ApplicationUser>>(MockBehavior.Strict,
                Mock.Of<IUserStore<ApplicationUser>>(), null!, null!, null!, null!, null!, null!, null!, null!);
            Users.SetupAllProperties(); // Includes virtual properties assigned by the Identity constructor.
            Users.Protected().Setup("Dispose", ItExpr.IsAny<bool>()).CallBase();
            Users.Object.PasswordHasher = new PasswordHasher<ApplicationUser>();
            Users.Setup(manager => manager.FindByEmailAsync(It.IsAny<string>()))
                .ReturnsAsync((string value) => value == User.Email ? User : null);
            Users.Setup(manager => manager.IsLockedOutAsync(User)).ReturnsAsync(() => LockedOut);
            Users.Setup(manager => manager.CheckPasswordAsync(User, It.IsAny<string>())).ReturnsAsync(() => PasswordValid);
            Users.Setup(manager => manager.GetRolesAsync(User)).ReturnsAsync(new List<string> { role });
            Users.Setup(manager => manager.AccessFailedAsync(User)).Returns(() =>
            {
                User.AccessFailedCount++;
                if (LockOnPasswordFailure) LockedOut = true;
                return Task.FromResult(IdentityResult.Success);
            });
            Users.Setup(manager => manager.ResetAccessFailedCountAsync(User)).Returns(() =>
            {
                User.AccessFailedCount = 0;
                return Task.FromResult(IdentityResult.Success);
            });
            Jwt.Setup(issuer => issuer.GenerateTokenAsync(User)).ReturnsAsync("synthetic-access");
            Jwt.Setup(issuer => issuer.GenerateRefreshToken()).Returns("synthetic-refresh");
            var publisher = new Mock<INotificationPublisher>(MockBehavior.Strict);
            publisher.Setup(service => service.PublishEmailAsync(It.IsAny<EmailNotificationMessage>(), It.IsAny<CancellationToken>()))
                .Callback<EmailNotificationMessage, CancellationToken>((message, _) => Emails.Add(message))
                .Returns(Task.CompletedTask);
            var audit = new SecurityAuditService(Db,
                new HttpContextAccessor { HttpContext = new DefaultHttpContext() });
            Service = new AuthService(Users.Object, Db, Jwt.Object,
                new Mock<ITherapistService>(MockBehavior.Strict).Object, publisher.Object, audit);
        }

        public static async Task<Fixture> CreateAsync(bool twoFactor = true,
            string email = "entry@example.test", string role = "Client")
        {
            var fixture = new Fixture(twoFactor, email, role);
            fixture.Db.Users.Add(fixture.User);
            await fixture.Db.SaveChangesAsync();
            return fixture;
        }

        public LoginRequestDto Request(bool rememberMe = false) => new()
        {
            Email = User.Email!, Password = "synthetic-password", RememberMe = rememberMe
        };

        public async Task EnterAsync(bool twoFactorEntry)
        {
            if (twoFactorEntry) await Service.LoginWith2FAAsync(Request());
            else await Service.LoginAsync(Request());
        }

        public async Task AssertNoAuthPairAsync()
        {
            Jwt.Verify(issuer => issuer.GenerateTokenAsync(It.IsAny<ApplicationUser>()), Times.Never);
            Jwt.Verify(issuer => issuer.GenerateRefreshToken(), Times.Never);
            Assert.Empty(await Db.RefreshTokens.AsNoTracking().ToListAsync());
            Assert.Null(User.LastLoginAtUtc);
            Assert.DoesNotContain(await Db.SecurityAuditLogs.ToListAsync(), audit => audit.EventType == "LoginSucceeded");
        }

        public async Task AssertAuthPairAsync(AuthResponseDto response, bool rememberMe)
        {
            Assert.Equal("synthetic-access", response.Token);
            Assert.Equal("synthetic-refresh", response.RefreshToken);
            Assert.Equal(User.Id, response.Id);
            Assert.Equal(Role, response.Role);
            Jwt.Verify(issuer => issuer.GenerateTokenAsync(User), Times.Once);
            Jwt.Verify(issuer => issuer.GenerateRefreshToken(), Times.Once);
            var row = Assert.Single(await Db.RefreshTokens.AsNoTracking().ToListAsync());
            Assert.Equal(User.Id, row.UserId);
            Assert.Equal(TimeSpan.FromDays(rememberMe ? 30 : 1), row.ExpiresAtUtc - row.IssuedAtUtc);
            Assert.True(Guid.TryParseExact(row.SessionId, "N", out _));
            Assert.Null(row.RevokedAtUtc);
            Assert.Null(row.ReplacedByTokenHash);
            Assert.NotEqual(response.RefreshToken, row.TokenHash);
            Assert.NotNull(User.LastLoginAtUtc);
            Assert.Contains(await Db.SecurityAuditLogs.ToListAsync(), audit =>
                audit.EventType == "LoginSucceeded" && audit.IsSuccessful);
        }

        public async ValueTask DisposeAsync()
        {
            try { Users.Object.Dispose(); }
            finally { await Db.DisposeAsync(); }
        }
    }
}
