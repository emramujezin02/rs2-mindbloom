using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using System.Security.Cryptography;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.Shared.Constants;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Enums;
namespace MindBloom.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;

    private readonly IJwtTokenService _jwtTokenService;
    private readonly ITherapistService
    _therapistService;
    private readonly ApplicationDbContext _context;

    private readonly INotificationPublisher
        _notificationPublisher;
    public AuthService(
        UserManager<ApplicationUser> userManager,
        IJwtTokenService jwtTokenService,
        ApplicationDbContext context,
        ITherapistService therapistService,
        INotificationPublisher notificationPublisher)
    {
        _userManager =
            userManager;

        _jwtTokenService =
            jwtTokenService;

        _context =
            context;

        _therapistService =
    therapistService;

        _notificationPublisher =
            notificationPublisher;
    }

    private bool IsDemoAccount(string email)
    {
        var demoEmails = new List<string>
    {
        "therapist@mindbloom.ba",
        "client@mindbloom.ba",
        "admin@mindbloom.ba"
    };

        return demoEmails.Contains(
            email.ToLower());
    }

    public async Task<AuthResponseDto> RegisterAsync(
    RegisterRequestDto request)
    {
        const string clientRole = RoleConstants.Client;

        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var normalizedUsername =
            request.Username.Trim();

        var normalizedGender =
            request.Gender.Trim();

        var allowedGenders =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "Male",
            "Female",
            "Other"
            };

        BusinessRuleGuard.Against(
            !allowedGenders.Contains(
                normalizedGender),
            "Gender must be Male, Female or Other.");

        var existingEmailUser =
            await _userManager
                .FindByEmailAsync(
                    normalizedEmail);

        BusinessRuleGuard.Against(
            existingEmailUser != null,
            "A user with this email already exists.");

        var existingUsernameUser =
            await _userManager
                .FindByNameAsync(
                    normalizedUsername);

        BusinessRuleGuard.Against(
            existingUsernameUser != null,
            "A user with this username already exists.");

        var user =
            new ApplicationUser
            {
                FirstName =
                    request.FirstName.Trim(),

                LastName =
                    request.LastName.Trim(),

                Email =
                    normalizedEmail,

                UserName =
                    normalizedUsername,

                DateOfBirth =
                    request.DateOfBirth,

                Gender =
                    normalizedGender,

                CreatedAtUtc =
                    DateTime.UtcNow,

                EmailConfirmed =
                    IsDemoAccount(
                        normalizedEmail),

                IsEmailVerified =
                    IsDemoAccount(
                        normalizedEmail)
            };

        var createResult =
            await _userManager
                .CreateAsync(
                    user,
                    request.Password);

        if (!createResult.Succeeded)
        {
            throw new Exception(
                string.Join(
                    ", ",
                    createResult.Errors
                        .Select(
                            error =>
                                error.Description)));
        }

        var addRoleResult =
            await _userManager
                .AddToRoleAsync(
                    user,
                    clientRole);

        if (!addRoleResult.Succeeded)
        {
            await _userManager
                .DeleteAsync(user);

            throw new Exception(
                string.Join(
                    ", ",
                    addRoleResult.Errors
                        .Select(
                            error =>
                                error.Description)));
        }

        var client =
            new Client
            {
                UserId =
                    user.Id
            };

        _context.Clients.Add(
            client);

        try
        {
            await _context
                .SaveChangesAsync();
        }
        catch
        {
            await _userManager
                .DeleteAsync(user);

            throw;
        }

        if (!IsDemoAccount(
                user.Email!))
        {
            await SendEmailVerificationCodeAsync(
                user.Email!);
        }

        var token =
            await _jwtTokenService
                .GenerateTokenAsync(
                    user);

        var refreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

        var now =
            DateTime.UtcNow;

        var refreshTokenEntity =
            new RefreshToken
            {
                UserId =
                    user.Id,

                TokenHash =
                    HashRefreshToken(
                        refreshToken),

                IssuedAtUtc =
                    now,

                ExpiresAtUtc =
                    now.AddDays(7),

                RevokedAtUtc =
                    null,

                ReplacedByTokenHash =
                    null,

                SessionId =
                    Guid.NewGuid()
                        .ToString("N")
            };

        _context.RefreshTokens.Add(
            refreshTokenEntity);

        await _context
            .SaveChangesAsync();

        return new AuthResponseDto
        {
            Id =
                user.Id,

            FirstName =
                user.FirstName,

            LastName =
                user.LastName,

            Email =
                user.Email!,

            Token =
                token,

            Role =
                clientRole,

            RefreshToken =
                refreshToken
        };
    }

    public async Task<
    RegisterTherapistResponseDto>
    RegisterTherapistAsync(
        RegisterTherapistRequestDto request)
    {
        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var normalizedUsername =
            request.Username.Trim();

        var normalizedGender =
            request.Gender.Trim();

        var existingEmailUser =
            await _userManager
                .FindByEmailAsync(
                    normalizedEmail);

        BusinessRuleGuard.Against(
            existingEmailUser != null,
            "A user with this email already exists.");

        var existingUsernameUser =
            await _userManager
                .FindByNameAsync(
                    normalizedUsername);

        BusinessRuleGuard.Against(
            existingUsernameUser != null,
            "A user with this username already exists.");

        var allowedGenders =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "Male",
            "Female",
            "Other"
            };

        BusinessRuleGuard.Against(
            !allowedGenders.Contains(
                normalizedGender),
            "Gender must be Male, Female or Other.");

        var user =
            new ApplicationUser
            {
                FirstName =
                    request.FirstName.Trim(),

                LastName =
                    request.LastName.Trim(),

                Email =
                    normalizedEmail,

                UserName =
                    normalizedUsername,

                DateOfBirth =
                    request.DateOfBirth,

                Gender =
                    normalizedGender,

                CreatedAtUtc =
                    DateTime.UtcNow,

                EmailConfirmed =
                    IsDemoAccount(
                        normalizedEmail),

                IsEmailVerified =
                    IsDemoAccount(
                        normalizedEmail),

                IsActive =
                    true
            };

        var createResult =
            await _userManager
                .CreateAsync(
                    user,
                    request.Password);

        if (!createResult.Succeeded)
        {
            var errors =
                string.Join(
                    ", ",
                    createResult.Errors
                        .Select(x =>
                            x.Description));

            throw new BadRequestException(
                errors);
        }

        try
        {
            var addRoleResult =
                await _userManager
                    .AddToRoleAsync(
                        user,
                        RoleConstants
                            .Therapist);

            if (!addRoleResult.Succeeded)
            {
                throw new BadRequestException(
                    string.Join(
                        ", ",
                        addRoleResult.Errors
                            .Select(x =>
                                x.Description)));
            }

            var therapist =
                await _therapistService
                    .CreateAsync(
                        user.Id,
                        new CreateTherapistDto
                        {
                            Specialization =
                                request
                                    .Specialization
                                    .Trim(),

                            Biography =
                                request
                                    .Biography
                                    .Trim(),

                            HourlyRate =
                                request.HourlyRate,

                            ExperienceYears =
                                request
                                    .ExperienceYears,

                            Country =
                                request.Country
                                    .Trim(),

                            City =
                                request.City
                                    .Trim(),

                            Address =
                                request.Address
                                    .Trim(),

                            OffersOnline =
                                request
                                    .OffersOnline,

                            OffersInPerson =
                                request
                                    .OffersInPerson
                        });

            if (!IsDemoAccount(
                    normalizedEmail))
            {
                await SendEmailVerificationCodeAsync(
                    normalizedEmail);
            }

            return new RegisterTherapistResponseDto
            {
                UserId =
                    user.Id,

                TherapistId =
                    therapist.Id,

                Email =
                    normalizedEmail,

                VerificationStatus =
                    TherapistVerificationStatus
                        .Pending
                        .ToString(),

                Message =
                    "Therapist registration submitted successfully. "
                    + "Your profile is pending verification."
            };
        }
        catch
        {
            await _userManager
                .DeleteAsync(user);

            throw;
        }
    }

    public async Task<AuthResponseDto> LoginAsync(
    LoginRequestDto request)
    {
        var user =
            await _userManager
                .FindByEmailAsync(
                    request.Email);

        if (user == null)
        {
            throw new Exception(
                "Invalid credentials.");
        }

        if (user.IsBlocked)
        {
            throw new Exception(
                "Your account is blocked.");
        }

        if (!user.IsEmailVerified &&
            !IsDemoAccount(
                user.Email!))
        {
            throw new Exception(
                "Email is not verified.");
        }

        var isPasswordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.Password);

        if (!isPasswordValid)
        {
            throw new Exception(
                "Invalid credentials.");
        }

        var roles =
            await _userManager
                .GetRolesAsync(
                    user);

        if (roles.Count == 0)
        {
            throw new InvalidOperationException(
                "User does not have an assigned role.");
        }

        var token =
            await _jwtTokenService
                .GenerateTokenAsync(
                    user);

        var refreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

        var now =
            DateTime.UtcNow;

        var refreshTokenEntity =
            new RefreshToken
            {
                UserId =
                    user.Id,

                TokenHash =
                    HashRefreshToken(
                        refreshToken),

                IssuedAtUtc =
                    now,

                ExpiresAtUtc =
                    request.RememberMe
                        ? now.AddDays(30)
                        : now.AddDays(1),

                RevokedAtUtc =
                    null,

                ReplacedByTokenHash =
                    null,

                SessionId =
                    Guid.NewGuid()
                        .ToString("N")
            };

        _context.RefreshTokens.Add(
            refreshTokenEntity);

        user.LastLoginAtUtc =
            now;

        await _context
            .SaveChangesAsync();

        return new AuthResponseDto
        {
            Id =
                user.Id,

            FirstName =
                user.FirstName,

            LastName =
                user.LastName,

            Email =
                user.Email!,

            Token =
                token,

            Role =
                roles.First(),

            RefreshToken =
                refreshToken
        };
    }

    public async Task ForgotPasswordAsync(
    ForgotPasswordDto request)
    {
        var user =
            await _userManager.FindByEmailAsync(
                request.Email);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var code =
            new Random()
                .Next(100000, 999999)
                .ToString();

        var resetCode =
            new PasswordResetCode
            {
                Email = request.Email,

                Code = code,

                ExpiresAtUtc =
                    DateTime.UtcNow.AddMinutes(10),

                IsUsed = false
            };

        _context.PasswordResetCodes.Add(resetCode);

        await _context.SaveChangesAsync();

        if (!IsDemoAccount(user.Email!))
        {
            await _notificationPublisher
                .PublishEmailAsync(
                    new EmailNotificationMessage
                    {
                        CorrelationId =
                            Guid.NewGuid(),

                        EventType =
                            NotificationEventType
                                .PasswordResetRequested,

                        RecipientEmail =
                            user.Email!,

                        RecipientName =
                            $"{user.FirstName} {user.LastName}"
                                .Trim(),

                        Subject =
                            "Reset Password Code",

                        Body =
                            $"Your reset code is: {code}",

                        IsHtml =
                            false,

                        Source =
                            "MindBloom.API"
                    });
        }
    }

    public async Task ResetPasswordAsync(
    ResetPasswordDto request)
    {
        var user =
            await _userManager.FindByEmailAsync(
                request.Email);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var resetCode =
            await _context.PasswordResetCodes
                .OrderByDescending(x => x.CreatedAtUtc)
                .FirstOrDefaultAsync(x =>
                    x.Email == request.Email
                    && x.Code == request.Code
                    && !x.IsUsed);

        if (resetCode == null)
        {
            throw new Exception("Invalid code.");
        }

        if (resetCode.ExpiresAtUtc < DateTime.UtcNow)
        {
            throw new Exception("Code expired.");
        }

        var resetToken =
            await _userManager
                .GeneratePasswordResetTokenAsync(user);

        var result =
            await _userManager
                .ResetPasswordAsync(
                    user,
                    resetToken,
                    request.NewPassword);

        if (!result.Succeeded)
        {
            throw new Exception(
                result.Errors.First().Description);
        }

        resetCode.IsUsed = true;

        await RevokeAllUserSessionsAsync(
    user.Id,
    DateTime.UtcNow);

        await _context.SaveChangesAsync();
    }

    public async Task ChangePasswordAsync(
     int userId,
     ChangePasswordDto request)
    {
        var user =
            await _userManager
                .FindByIdAsync(
                    userId.ToString());

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        if (string.IsNullOrWhiteSpace(
                request.CurrentPassword))
        {
            throw new BadRequestException(
                "Current password is required.");
        }

        if (string.IsNullOrWhiteSpace(
                request.NewPassword))
        {
            throw new BadRequestException(
                "New password is required.");
        }

        if (request.CurrentPassword ==
            request.NewPassword)
        {
            throw new BadRequestException(
                "New password must be different from the current password.");
        }

        var result =
            await _userManager
                .ChangePasswordAsync(
                    user,
                    request.CurrentPassword,
                    request.NewPassword);

        if (!result.Succeeded)
        {
            var errorMessage =
                result.Errors
                    .Select(x =>
                        x.Description)
                    .FirstOrDefault();

            throw new BadRequestException(
                string.IsNullOrWhiteSpace(
                    errorMessage)
                    ? "Password could not be changed."
                    : errorMessage);
        }

        await RevokeAllUserSessionsAsync(
            userId,
            DateTime.UtcNow);
    }

    public async Task SendVerificationEmailAsync(
    string email)
    {
        var user =
            await _userManager
                .FindByEmailAsync(email);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var token =
            await _userManager
                .GenerateEmailConfirmationTokenAsync(
                    user);

        var encodedToken =
            Uri.EscapeDataString(token);

        var verificationLink =
            $"http://localhost:5110/api/auth/verify-email?email={user.Email}&token={encodedToken}";

        var body =
    $@"Click the link below to verify your email:

{verificationLink}";

        await _notificationPublisher
            .PublishEmailAsync(
                new EmailNotificationMessage
                {
                    CorrelationId =
                        Guid.NewGuid(),

                    EventType =
                        NotificationEventType
                            .EmailVerificationRequested,

                    RecipientEmail =
                        user.Email!,

                    RecipientName =
                        $"{user.FirstName} {user.LastName}"
                            .Trim(),

                    Subject =
                        "MindBloom Email Verification",

                    Body =
                        body,

                    IsHtml =
                        false,

                    Source =
                        "MindBloom.API"
                });
    }

    public async Task VerifyEmailAsync(
    VerifyEmailDto request)
    {
        var user =
            await _userManager
                .FindByEmailAsync(request.Email);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var result =
            await _userManager
                .ConfirmEmailAsync(
                    user,
                    request.Token);

        if (!result.Succeeded)
        {
            throw new Exception(
                "Invalid verification token.");
        }

        user.IsEmailVerified = true;

        await _userManager.UpdateAsync(user);
    }

    public async Task<AuthResponseDto>
    RefreshTokenAsync(
        RefreshTokenRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(
                request.RefreshToken))
        {
            throw new UnauthorizedAccessException(
                "Invalid refresh token.");
        }

        var tokenHash =
            HashRefreshToken(
                request.RefreshToken);

        var refreshToken =
            await _context.RefreshTokens
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.TokenHash ==
                        tokenHash);

        if (refreshToken == null)
        {
            throw new UnauthorizedAccessException(
                "Invalid refresh token.");
        }

        var now =
            DateTime.UtcNow;

        /*
         * REUSE DETECTION:
         * Ako je već opozvan token ponovo
         * iskorišten, smatramo da je session
         * chain potencijalno kompromitovan.
         */
        if (refreshToken.RevokedAtUtc.HasValue)
        {
            await RevokeSessionAsync(
                refreshToken.UserId,
                refreshToken.SessionId,
                now);

            throw new UnauthorizedAccessException(
                "Refresh token reuse detected.");
        }

        if (refreshToken.ExpiresAtUtc <=
            now)
        {
            refreshToken.RevokedAtUtc =
                now;

            await _context.SaveChangesAsync();

            throw new UnauthorizedAccessException(
                "Refresh token expired.");
        }

        if (refreshToken.User.IsBlocked ||
            !refreshToken.User.IsActive)
        {
            await RevokeAllUserSessionsAsync(
                refreshToken.UserId,
                now);

            throw new UnauthorizedAccessException(
                "User session is no longer valid.");
        }

        var newJwtToken =
            await _jwtTokenService
                .GenerateTokenAsync(
                    refreshToken.User);

        var newRefreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

        var newRefreshTokenHash =
            HashRefreshToken(
                newRefreshToken);

        /*
         * Stari token postaje nevažeći
         * prije izdavanja novog.
         */
        refreshToken.RevokedAtUtc =
            now;

        refreshToken.ReplacedByTokenHash =
            newRefreshTokenHash;

        var newRefreshTokenEntity =
            new RefreshToken
            {
                UserId =
                    refreshToken.UserId,

                TokenHash =
                    newRefreshTokenHash,

                IssuedAtUtc =
                    now,

                ExpiresAtUtc =
                    refreshToken.ExpiresAtUtc,

                RevokedAtUtc =
                    null,

                ReplacedByTokenHash =
                    null,

                SessionId =
                    refreshToken.SessionId
            };

        _context.RefreshTokens.Add(
            newRefreshTokenEntity);

        await _context.SaveChangesAsync();

        var roles =
            await _userManager
                .GetRolesAsync(
                    refreshToken.User);

        return new AuthResponseDto
        {
            Token =
                newJwtToken,

            RefreshToken =
                newRefreshToken,

            Id =
                refreshToken.UserId,

            FirstName =
                refreshToken.User.FirstName,

            LastName =
                refreshToken.User.LastName,

            Email =
                refreshToken.User.Email
                ?? string.Empty,

            Role =
                roles.FirstOrDefault()
                ?? string.Empty
        };
    }

    public async Task DeleteAccountAsync(
    int userId,
    DeleteAccountRequestDto request)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var isPasswordCorrect =
            await _userManager.CheckPasswordAsync(
                user,
                request.Password);

        if (!isPasswordCorrect)
        {
            throw new Exception("Invalid password.");
        }

        var refreshTokens =
            await _context.RefreshTokens
                .Where(x => x.UserId == user.Id)
                .ToListAsync();

        _context.RefreshTokens.RemoveRange(
            refreshTokens);

        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == user.Id);

        if (therapist != null)
        {
            _context.Therapists.Remove(therapist);
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == user.Id);

        if (client != null)
        {
            _context.Clients.Remove(client);
        }

        await _context.SaveChangesAsync();

        var result =
            await _userManager.DeleteAsync(user);

        if (!result.Succeeded)
        {
            throw new Exception(
                "Failed to delete account.");
        }
    }

    public async Task<Login2FAResponseDto>
    LoginWith2FAAsync(
        LoginRequestDto request)
    {
        var user =
            await _userManager.FindByEmailAsync(
                request.Email);

        if (user == null)
        {
            throw new Exception(
                "Invalid credentials.");
        }

        if (user.IsBlocked)
        {
            throw new Exception(
                "Your account is blocked.");
        }

        if (!user.IsEmailVerified &&
            !IsDemoAccount(user.Email!))
        {
            throw new Exception(
                "Email is not verified.");
        }

        var isPasswordValid =
            await _userManager.CheckPasswordAsync(
                user,
                request.Password);

        if (!isPasswordValid)
        {
            throw new Exception(
                "Invalid credentials.");
        }

        if (!user.TwoFactorEnabledCustom ||
            IsDemoAccount(user.Email!))
        {
            var authResponse =
                await LoginAsync(request);

            return new Login2FAResponseDto
            {
                RequiresTwoFactor = false,
                Message =
                    "Login successful.",
                Auth = authResponse
            };
        }

        var code =
            System.Security.Cryptography
                .RandomNumberGenerator
                .GetInt32(100000, 1000000)
                .ToString();

        user.TwoFactorCode = code;

        user.TwoFactorCodeExpiresAtUtc =
            DateTime.UtcNow.AddMinutes(5);

        await _userManager.UpdateAsync(user);

        await _notificationPublisher
            .PublishEmailAsync(
                new EmailNotificationMessage
                {
                    CorrelationId =
                        Guid.NewGuid(),

                    EventType =
                        NotificationEventType
                            .TwoFactorCodeRequested,

                    RecipientEmail =
                        user.Email!,

                    RecipientName =
                        $"{user.FirstName} {user.LastName}"
                            .Trim(),

                    Subject =
                        "MindBloom 2FA Code",

                    Body =
                        $"Your verification code is: {code}",

                    IsHtml =
                        false,

                    Source =
                        "MindBloom.API"
                });

        return new Login2FAResponseDto
        {
            RequiresTwoFactor = true,
            Message =
                "A verification code has been sent to your email.",
            Auth = null
        };
    }

    public async Task<AuthResponseDto>
     Verify2FAAsync(
         Verify2FADto request)
    {
        var user =
            await _userManager
                .FindByEmailAsync(
                    request.Email);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        if (!user.TwoFactorEnabledCustom)
        {
            throw new Exception(
                "Two-factor authentication is not enabled.");
        }

        if (string.IsNullOrWhiteSpace(
                user.TwoFactorCode))
        {
            throw new Exception(
                "No active verification code exists.");
        }

        if (user.TwoFactorCodeExpiresAtUtc ==
                null ||
            user.TwoFactorCodeExpiresAtUtc <
                DateTime.UtcNow)
        {
            user.TwoFactorCode =
                null;

            user.TwoFactorCodeExpiresAtUtc =
                null;

            await _userManager
                .UpdateAsync(user);

            throw new Exception(
                "Verification code expired.");
        }

        if (user.TwoFactorCode !=
            request.Code.Trim())
        {
            throw new Exception(
                "Invalid verification code.");
        }

        user.TwoFactorCode =
            null;

        user.TwoFactorCodeExpiresAtUtc =
            null;

        await _userManager
            .UpdateAsync(user);

        var roles =
            await _userManager
                .GetRolesAsync(
                    user);

        if (roles.Count == 0)
        {
            throw new InvalidOperationException(
                "User does not have an assigned role.");
        }

        var token =
            await _jwtTokenService
                .GenerateTokenAsync(
                    user);

        var refreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

        var now =
            DateTime.UtcNow;

        var refreshTokenEntity =
            new RefreshToken
            {
                UserId =
                    user.Id,

                TokenHash =
                    HashRefreshToken(
                        refreshToken),

                IssuedAtUtc =
                    now,

                ExpiresAtUtc =
                    now.AddDays(7),

                RevokedAtUtc =
                    null,

                ReplacedByTokenHash =
                    null,

                SessionId =
                    Guid.NewGuid()
                        .ToString("N")
            };

        _context.RefreshTokens.Add(
            refreshTokenEntity);

        user.LastLoginAtUtc =
            now;

        await _context
            .SaveChangesAsync();

        return new AuthResponseDto
        {
            Id =
                user.Id,

            FirstName =
                user.FirstName,

            LastName =
                user.LastName,

            Email =
                user.Email!,

            Token =
                token,

            RefreshToken =
                refreshToken,

            Role =
                roles.First()
        };
    }

    public async Task Enable2FAAsync(
    int userId)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        user.TwoFactorEnabledCustom = true;

        await _userManager.UpdateAsync(user);
    }

    public async Task Disable2FAAsync(
    int userId)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        user.TwoFactorEnabledCustom = false;

        await _userManager.UpdateAsync(user);
    }

    public async Task LogoutAsync(
     int userId,
     string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(
                refreshToken))
        {
            throw new BadRequestException(
                "Refresh token is required.");
        }

        var tokenHash =
            HashRefreshToken(
                refreshToken);

        var token =
            await _context.RefreshTokens
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                        userId &&
                    x.TokenHash ==
                        tokenHash);

        if (token == null)
        {
            return;
        }

        if (token.RevokedAtUtc.HasValue)
        {
            return;
        }

        await RevokeSessionAsync(
            userId,
            token.SessionId,
            DateTime.UtcNow);
    }

    public async Task<bool>
    Is2FAEnabledAsync(
        int userId)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        return user.TwoFactorEnabledCustom;
    }

    public async Task
    SendEmailVerificationCodeAsync(
        string email)
    {
        var normalizedEmail =
            email.Trim().ToLowerInvariant();

        var user =
            await _userManager.FindByEmailAsync(
                normalizedEmail);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        if (user.IsEmailVerified ||
            user.EmailConfirmed)
        {
            throw new BusinessException(
                "Email is already verified.");
        }

        var previousCodes =
            await _context.EmailVerificationCodes
                .Where(x =>
                    x.UserId == user.Id &&
                    !x.IsUsed)
                .ToListAsync();

        foreach (var previousCode
                 in previousCodes)
        {
            previousCode.IsUsed = true;
        }

        var code =
            RandomNumberGenerator
                .GetInt32(100000, 1000000)
                .ToString();

        var codeHash =
            _userManager.PasswordHasher
                .HashPassword(
                    user,
                    code);

        var verificationCode =
            new EmailVerificationCode
            {
                UserId = user.Id,
                CodeHash = codeHash,
                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddMinutes(10),
                IsUsed = false
            };

        _context.EmailVerificationCodes.Add(
            verificationCode);

        await _context.SaveChangesAsync();

        if (!IsDemoAccount(user.Email!))
        {
            await _notificationPublisher
                .PublishEmailAsync(
                    new EmailNotificationMessage
                    {
                        CorrelationId =
                            Guid.NewGuid(),

                        EventType =
                            NotificationEventType
                                .EmailVerificationRequested,

                        RecipientEmail =
                            user.Email!,

                        RecipientName =
                            $"{user.FirstName} {user.LastName}"
                                .Trim(),

                        Subject =
                            "MindBloom Email Verification",

                        Body =
                            $"Your email verification code is: {code}. "
                            + "The code expires in 10 minutes.",

                        IsHtml =
                            false,

                        Source =
                            "MindBloom.API"
                    });
        }
    }

    public async Task VerifyEmailCodeAsync(
    VerifyEmailCodeDto request)
    {
        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var user =
            await _userManager.FindByEmailAsync(
                normalizedEmail);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        if (user.IsEmailVerified &&
            user.EmailConfirmed)
        {
            return;
        }

        var verificationCode =
            await _context.EmailVerificationCodes
                .Where(x =>
                    x.UserId == user.Id &&
                    !x.IsUsed)
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .FirstOrDefaultAsync();

        if (verificationCode == null)
        {
            throw new Exception(
                "No active verification code exists.");
        }

        if (verificationCode.ExpiresAtUtc <
            DateTime.UtcNow)
        {
            verificationCode.IsUsed = true;

            await _context.SaveChangesAsync();

            throw new Exception(
                "Verification code expired.");
        }

        var verificationResult =
            _userManager.PasswordHasher
                .VerifyHashedPassword(
                    user,
                    verificationCode.CodeHash,
                    request.Code.Trim());

        if (verificationResult ==
            PasswordVerificationResult.Failed)
        {
            throw new Exception(
                "Invalid verification code.");
        }

        verificationCode.IsUsed = true;

        user.IsEmailVerified = true;
        user.EmailConfirmed = true;

        await _userManager.UpdateAsync(user);

        await _context.SaveChangesAsync();
    }
    private static string HashRefreshToken(
    string token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new BadRequestException(
                "Refresh token is required.");
        }

        var bytes =
            System.Text.Encoding.UTF8
                .GetBytes(token.Trim());

        var hash =
            SHA256.HashData(bytes);

        return Convert.ToHexString(hash);
    }

    private async Task RevokeSessionAsync(
    int userId,
    string sessionId,
    DateTime revokedAtUtc)
    {
        var sessionTokens =
            await _context.RefreshTokens
                .Where(x =>
                    x.UserId ==
                        userId &&
                    x.SessionId ==
                        sessionId &&
                    !x.RevokedAtUtc.HasValue)
                .ToListAsync();

        foreach (var token
                 in sessionTokens)
        {
            token.RevokedAtUtc =
                revokedAtUtc;
        }

        await _context.SaveChangesAsync();
    }

    private async Task
    RevokeAllUserSessionsAsync(
        int userId,
        DateTime revokedAtUtc)
    {
        var activeTokens =
            await _context.RefreshTokens
                .Where(x =>
                    x.UserId ==
                        userId &&
                    !x.RevokedAtUtc.HasValue)
                .ToListAsync();

        foreach (var token
                 in activeTokens)
        {
            token.RevokedAtUtc =
                revokedAtUtc;
        }

        await _context.SaveChangesAsync();
    }

    public async Task LogoutAllAsync(
    int userId)
    {
        if (userId <= 0)
        {
            throw new BadRequestException(
                "User identifier is invalid.");
        }

        var userExists =
            await _context.Users
                .AsNoTracking()
                .AnyAsync(x =>
                    x.Id == userId);

        if (!userExists)
        {
            throw new NotFoundException(
                "User not found.");
        }

        await RevokeAllUserSessionsAsync(
            userId,
            DateTime.UtcNow);
    }


}