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
using System.Text;
using Microsoft.AspNetCore.WebUtilities;
using MindBloom.Application.Features.Security.DTOs;
using MindBloom.Application.Features.Security.Interfaces;

namespace MindBloom.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;

    private readonly IJwtTokenService _jwtTokenService;
    private readonly ITherapistService _therapistService;
    private readonly ISecurityAuditService _securityAuditService;
    private readonly ApplicationDbContext _context;
    private readonly INotificationPublisher _notificationPublisher;

    public AuthService(
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext context,
        IJwtTokenService jwtTokenService,
        ITherapistService therapistService,
        INotificationPublisher notificationPublisher,
        ISecurityAuditService securityAuditService)
    {
        _userManager = userManager;

        _jwtTokenService = jwtTokenService;

        _context = context;

        _therapistService = therapistService;

        _notificationPublisher = notificationPublisher;

        _securityAuditService = securityAuditService;
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

        BusinessRuleGuard.Against(
    !request.AcceptPrivacyPolicy,
    "Privacy policy must be accepted.");

        BusinessRuleGuard.Against(
            !string.Equals(
                request.PrivacyPolicyVersion,
                ConsentDocumentConstants
                    .PrivacyPolicyVersion,
                StringComparison.Ordinal),
            "The privacy policy version is no longer current.");

        BusinessRuleGuard.Against(
            !request.AcceptTermsOfService,
            "Terms of service must be accepted.");

        BusinessRuleGuard.Against(
            !string.Equals(
                request.TermsOfServiceVersion,
                ConsentDocumentConstants
                    .TermsOfServiceVersion,
                StringComparison.Ordinal),
            "The terms of service version is no longer current.");

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

        var consentAcceptedAtUtc =
    DateTime.UtcNow;

        _context.UserConsents.AddRange(
            new UserConsent
            {
                UserId =
                    user.Id,

                ConsentType =
                    UserConsentType
                        .PrivacyPolicy,

                DocumentVersion =
                    ConsentDocumentConstants
                        .PrivacyPolicyVersion,

                IsAccepted =
                    true,

                AcceptedAtUtc =
                    consentAcceptedAtUtc
            },

            new UserConsent
            {
                UserId =
                    user.Id,

                ConsentType =
                    UserConsentType
                        .TermsOfService,

                DocumentVersion =
                    ConsentDocumentConstants
                        .TermsOfServiceVersion,

                IsAccepted =
                    true,

                AcceptedAtUtc =
                    consentAcceptedAtUtc
            });

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

        BusinessRuleGuard.Against(
    !request.AcceptPrivacyPolicy,
    "Privacy policy must be accepted.");

        BusinessRuleGuard.Against(
            !string.Equals(
                request.PrivacyPolicyVersion,
                ConsentDocumentConstants
                    .PrivacyPolicyVersion,
                StringComparison.Ordinal),
            "The privacy policy version is no longer current.");

        BusinessRuleGuard.Against(
            !request.AcceptTermsOfService,
            "Terms of service must be accepted.");

        BusinessRuleGuard.Against(
            !string.Equals(
                request.TermsOfServiceVersion,
                ConsentDocumentConstants
                    .TermsOfServiceVersion,
                StringComparison.Ordinal),
            "The terms of service version is no longer current.");

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

            var consentAcceptedAtUtc =
    DateTime.UtcNow;

            _context.UserConsents.AddRange(
                new UserConsent
                {
                    UserId =
                        user.Id,

                    ConsentType =
                        UserConsentType
                            .PrivacyPolicy,

                    DocumentVersion =
                        ConsentDocumentConstants
                            .PrivacyPolicyVersion,

                    IsAccepted =
                        true,

                    AcceptedAtUtc =
                        consentAcceptedAtUtc
                },

                new UserConsent
                {
                    UserId =
                        user.Id,

                    ConsentType =
                        UserConsentType
                            .TermsOfService,

                    DocumentVersion =
                        ConsentDocumentConstants
                            .TermsOfServiceVersion,

                    IsAccepted =
                        true,

                    AcceptedAtUtc =
                        consentAcceptedAtUtc
                });

            await _context
                .SaveChangesAsync();

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
        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var user =
            await _userManager
                .FindByEmailAsync(
                    normalizedEmail);

        if (user == null)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            null,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "InvalidCredentials",

                        ResourceType =
                            "Authentication"
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (user.IsBlocked ||
            !user.IsActive)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "AccountUnavailable",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (await _userManager
        .IsLockedOutAsync(user))
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "AccountTemporarilyLocked",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (!user.IsEmailVerified &&
            !IsDemoAccount(
                user.Email!))
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "EmailNotVerified",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Email is not verified.");
        }

        var isPasswordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.Password);

        if (!isPasswordValid)
        {
            var accessFailedResult =
                await _userManager
                    .AccessFailedAsync(
                        user);

            if (!accessFailedResult.Succeeded)
            {
                throw new UnauthorizedException(
                    "Invalid credentials.");
            }

            var isNowLockedOut =
                await _userManager
                    .IsLockedOutAsync(
                        user);

            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            isNowLockedOut
                                ? "AccountTemporarilyLocked"
                                : "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            isNowLockedOut
                                ? "MaximumFailedLoginAttemptsExceeded"
                                : "InvalidCredentials",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (user.AccessFailedCount > 0)
        {
            var resetFailedResult =
                await _userManager
                    .ResetAccessFailedCountAsync(
                        user);

            if (!resetFailedResult.Succeeded)
            {
                throw new InvalidOperationException(
                    "Login state could not be updated.");
            }
        }

        var roles =
            await _userManager
                .GetRolesAsync(
                    user);

        if (roles.Count == 0)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "MissingRole",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

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

        await _securityAuditService
            .WriteAsync(
                new SecurityAuditWriteDto
                {
                    UserId =
                        user.Id,

                    EventType =
                        "LoginSucceeded",

                    IsSuccessful =
                        true,

                    FailureReason =
                        null,

                    ResourceType =
                        "Authentication",

                    ResourceId =
                        user.Id.ToString()
                });

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
        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var user =
            await _userManager
                .FindByEmailAsync(
                    normalizedEmail);

        if (user == null)
        {
            return;
        }

        var resetToken =
            await _userManager
                .GeneratePasswordResetTokenAsync(
                    user);

        var encodedToken =
            WebEncoders.Base64UrlEncode(
                Encoding.UTF8.GetBytes(
                    resetToken));

        var tokenHash =
            HashPasswordResetToken(
                encodedToken);

        var now =
            DateTime.UtcNow;

        var previousRequests =
            await _context.PasswordResetCodes
                .Where(x =>
                    x.Email ==
                        normalizedEmail &&
                    !x.IsUsed)
                .ToListAsync();

        foreach (var previousRequest
                 in previousRequests)
        {
            previousRequest.IsUsed =
                true;

            previousRequest.UsedAtUtc =
                now;
        }

        var resetRequest =
            new PasswordResetCode
            {
                Email =
                    normalizedEmail,

                TokenHash =
                    tokenHash,

                ExpiresAtUtc =
                    now.AddMinutes(15),

                IsUsed =
                    false,

                UsedAtUtc =
                    null
            };

        _context.PasswordResetCodes.Add(
            resetRequest);

        await _context
            .SaveChangesAsync();

        if (IsDemoAccount(
                user.Email!))
        {
            return;
        }

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
                        "MindBloom password reset",

                    Body =
                        "Use the following password reset token:\n\n"
                        + encodedToken
                        + "\n\nThis token expires in 15 minutes. "
                        + "If you did not request a password reset, "
                        + "you can ignore this email.",

                    IsHtml =
                        false,

                    Source =
                        "MindBloom.API"
                });
    }

    public async Task ResetPasswordAsync(
     ResetPasswordDto request)
    {
        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var safeErrorMessage =
            "Password reset request is invalid or has expired.";

        if (string.IsNullOrWhiteSpace(
                request.Token))
        {
            throw new BadRequestException(
                safeErrorMessage);
        }

        var user =
            await _userManager
                .FindByEmailAsync(
                    normalizedEmail);

        if (user == null)
        {
            throw new BadRequestException(
                safeErrorMessage);
        }

        var encodedToken =
            request.Token.Trim();

        var tokenHash =
            HashPasswordResetToken(
                encodedToken);

        var resetRequest =
            await _context.PasswordResetCodes
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .FirstOrDefaultAsync(x =>
                    x.Email ==
                        normalizedEmail &&
                    x.TokenHash ==
                        tokenHash &&
                    !x.IsUsed);

        if (resetRequest == null ||
            resetRequest.ExpiresAtUtc <=
                DateTime.UtcNow)
        {
            throw new BadRequestException(
                safeErrorMessage);
        }

        string identityToken;

        try
        {
            var tokenBytes =
                WebEncoders.Base64UrlDecode(
                    encodedToken);

            identityToken =
                Encoding.UTF8.GetString(
                    tokenBytes);
        }
        catch
        {
            throw new BadRequestException(
                safeErrorMessage);
        }

        var result =
            await _userManager
                .ResetPasswordAsync(
                    user,
                    identityToken,
                    request.NewPassword);

        if (!result.Succeeded)
        {
            throw new BadRequestException(
                safeErrorMessage);
        }

        var now =
            DateTime.UtcNow;

        resetRequest.IsUsed =
            true;

        resetRequest.UsedAtUtc =
            now;

        _context.UserAudits.Add(
            new UserAudit
            {
                TargetUserId =
                    user.Id,

                ChangedByUserId =
                    user.Id,

                Action =
                    "PasswordReset",

                PreviousValues =
                    null,

                NewValues =
                    null,

                Reason =
                    "Password reset completed through the self-service recovery flow.",

                ChangedAtUtc =
                    now
            });

        await RevokeAllUserSessionsAsync(
            user.Id,
            now);

        await _context
            .SaveChangesAsync();
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

        if (request.NewPassword !=
            request.ConfirmNewPassword)
        {
            throw new BadRequestException(
                "New password and confirmation do not match.");
        }

        if (request.CurrentPassword ==
            request.NewPassword)
        {
            throw new BadRequestException(
                "New password must be different from the current password.");
        }

        var currentPasswordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.CurrentPassword);

        if (!currentPasswordValid)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "PasswordChangeFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "CurrentPasswordIncorrect",

                        ResourceType =
                            "Account",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new BadRequestException(
                "Current password is incorrect.");
        }

        var result =
            await _userManager
                .ChangePasswordAsync(
                    user,
                    request.CurrentPassword,
                    request.NewPassword);

        if (!result.Succeeded)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "PasswordChangeFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "IdentityPasswordPolicyRejected",

                        ResourceType =
                            "Account",

                        ResourceId =
                            user.Id.ToString()
                    });

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

        var now =
            DateTime.UtcNow;

        await RevokeAllUserSessionsAsync(
            userId,
            now);

        await _securityAuditService
            .WriteAsync(
                new SecurityAuditWriteDto
                {
                    UserId =
                        user.Id,

                    EventType =
                        "PasswordChanged",

                    IsSuccessful =
                        true,

                    FailureReason =
                        null,

                    ResourceType =
                        "Account",

                    ResourceId =
                        user.Id.ToString()
                });
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
        if (request == null)
        {
            throw new BadRequestException(
                "Account deletion request is required.");
        }

        if (string.IsNullOrWhiteSpace(
                request.Password))
        {
            throw new BadRequestException(
                "Current password is required.");
        }

        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        if (!user.IsActive ||
            user.IsBlocked)
        {
            throw new BadRequestException(
                "Account is not available.");
        }

        var passwordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.Password);

        if (!passwordValid)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "AccountDeletionFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "IdentityConfirmationFailed",

                        ResourceType =
                            "Account",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Account deletion could not be confirmed.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == user.Id &&
                    !x.IsDeleted);

        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == user.Id &&
                    !x.IsDeleted);

        if (client != null)
        {
            var hasActiveClientAppointments =
                await _context.Appointments
                    .AsNoTracking()
                    .AnyAsync(x =>
                        x.ClientId ==
                            client.Id &&
                        !x.IsDeleted &&
                        (
                            x.Status ==
                                AppointmentStatus
                                    .Pending ||
                            x.Status ==
                                AppointmentStatus
                                    .Accepted
                        ));

            if (hasActiveClientAppointments)
            {
                await _securityAuditService
                    .WriteAsync(
                        new SecurityAuditWriteDto
                        {
                            UserId =
                                user.Id,

                            EventType =
                                "AccountDeletionFailed",

                            IsSuccessful =
                                false,

                            FailureReason =
                                "ActiveAppointmentsExist",

                            ResourceType =
                                "Account",

                            ResourceId =
                                user.Id.ToString()
                        });

                throw new BusinessException(
                    "Account cannot be deleted while active appointments exist. Cancel pending or accepted appointments first.");
            }
        }

        if (therapist != null)
        {
            var hasActiveTherapistAppointments =
                await _context.Appointments
                    .AsNoTracking()
                    .AnyAsync(x =>
                        x.TherapistId ==
                            therapist.Id &&
                        !x.IsDeleted &&
                        (
                            x.Status ==
                                AppointmentStatus
                                    .Pending ||
                            x.Status ==
                                AppointmentStatus
                                    .Accepted
                        ));

            if (hasActiveTherapistAppointments)
            {
                await _securityAuditService
                    .WriteAsync(
                        new SecurityAuditWriteDto
                        {
                            UserId =
                                user.Id,

                            EventType =
                                "AccountDeletionFailed",

                            IsSuccessful =
                                false,

                            FailureReason =
                                "ActiveAppointmentsExist",

                            ResourceType =
                                "Account",

                            ResourceId =
                                user.Id.ToString()
                        });

                throw new BusinessException(
                    "Account cannot be deleted while active appointments exist.");
            }
        }

        if (therapist != null)
        {
            var therapistDocumentIds =
                await _context
                    .TherapistDocuments
                    .AsNoTracking()
                    .Where(x =>
                        x.TherapistId ==
                            therapist.Id &&
                        !x.IsDeleted)
                    .Select(x => x.Id)
                    .ToListAsync();

            foreach (var documentId
                     in therapistDocumentIds)
            {
                await _therapistService
                    .DeleteDocumentAsync(
                        user.Id,
                        documentId);
            }
        }

        var now =
            DateTime.UtcNow;

        var strategy =
            _context.Database
                .CreateExecutionStrategy();

        await strategy.ExecuteAsync(
            async () =>
            {
                await using var transaction =
                    await _context.Database
                        .BeginTransactionAsync();

                try
                {
                    var activeRefreshTokens =
                await _context.RefreshTokens
                    .Where(x =>
                        x.UserId ==
                            user.Id &&
                        x.RevokedAtUtc ==
                            null)
                    .ToListAsync();

            foreach (var refreshToken
                     in activeRefreshTokens)
            {
                refreshToken.RevokedAtUtc =
                    now;
            }

            var fcmTokens =
                await _context.FcmDeviceTokens
                    .Where(x =>
                        x.UserId == user.Id)
                    .ToListAsync();

            _context.FcmDeviceTokens
                .RemoveRange(
                    fcmTokens);

            var twoFactorChallenges =
                await _context
                    .TwoFactorLoginChallenges
                    .Where(x =>
                        x.UserId == user.Id &&
                        !x.IsUsed)
                    .ToListAsync();

            foreach (var challenge
                     in twoFactorChallenges)
            {
                challenge.IsUsed =
                    true;

                challenge.UsedAtUtc =
                    now;
            }

            var verificationCodes =
                await _context
                    .EmailVerificationCodes
                    .Where(x =>
                        x.UserId == user.Id)
                    .ToListAsync();

            _context.EmailVerificationCodes
                .RemoveRange(
                    verificationCodes);

            var originalEmail =
                user.Email?
                    .Trim()
                    .ToLowerInvariant();

            if (!string.IsNullOrWhiteSpace(
                    originalEmail))
            {
                var resetCodes =
                    await _context
                        .PasswordResetCodes
                        .Where(x =>
                            x.Email
                                .ToLower() ==
                            originalEmail)
                        .ToListAsync();

                _context.PasswordResetCodes
                    .RemoveRange(
                        resetCodes);
            }

            if (client != null)
            {
                var privateJournalEntries =
                    await _context
                        .PrivateJournalEntries
                        .Where(x =>
                            x.ClientId ==
                                client.Id)
                        .ToListAsync();

                _context.PrivateJournalEntries
                    .RemoveRange(
                        privateJournalEntries);

                var moodEntries =
                    await _context.MoodEntries
                        .Where(x =>
                            x.ClientId ==
                                client.Id)
                        .ToListAsync();

                _context.MoodEntries
                    .RemoveRange(
                        moodEntries);

                var clientAppointmentIds =
                    await _context.Appointments
                        .Where(x =>
                            x.ClientId == client.Id)
                        .Select(x => x.Id)
                        .ToListAsync();

                if (clientAppointmentIds.Count > 0)
                {
                    var appointmentNotes =
                        await _context.AppointmentNotes
                            .Where(x =>
                                clientAppointmentIds
                                    .Contains(
                                        x.AppointmentId))
                            .ToListAsync();

                    _context.AppointmentNotes
                        .RemoveRange(
                            appointmentNotes);
                }

                client.Location =
                    null;

                client.PreferredTherapistGender =
                    null;

                client.PreferredSessionType =
                    null;

                client.MinimumPricePerSession =
                    null;

                client.MaximumPricePerSession =
                    null;

                client.PreferredLanguages =
                    null;

                client.AssessmentFocusAreas =
                    null;

                client.PreferredDays =
                    null;

                client.HasCompletedOnboarding =
                    false;

                client.OnboardingCompletedAtUtc =
                    null;

                var therapyPreferences =
                    await _context
                        .ClientTherapyApproaches
                        .Where(x =>
                            x.ClientId ==
                                client.Id)
                        .ToListAsync();

                _context.ClientTherapyApproaches
                    .RemoveRange(
                        therapyPreferences);
            }


            var appointmentStatusAudits =
                await _context.AppointmentStatusAudits
                    .Where(x =>
                        x.ChangedByUserId ==
                            user.Id)
                    .ToListAsync();

            foreach (var audit
                     in appointmentStatusAudits)
            {
                audit.Reason =
                    null;
            }

            var settings =
                await _context.UserSettings
                    .Where(x =>
                        x.UserId == user.Id)
                    .ToListAsync();

            _context.UserSettings
                .RemoveRange(
                    settings);

            var consents =
                await _context.UserConsents
                    .Where(x =>
                        x.UserId == user.Id)
                    .ToListAsync();

            _context.UserConsents
                .RemoveRange(
                    consents);

            var notifications =
                await _context.Notifications
                    .Where(x =>
                        x.UserId == user.Id)
                    .ToListAsync();

            _context.Notifications
                .RemoveRange(
                    notifications);

            var chatMessages =
                await _context.ChatMessages
                    .Where(x =>
                        x.SenderUserId ==
                            user.Id)
                    .ToListAsync();

            foreach (var message
                     in chatMessages)
            {
                message.Content =
                    "[Message removed]";

                message.IsEdited =
                    false;

                message.EditedAtUtc =
                    null;

                message.ClientMessageId =
                    null;
            }

            var conversationParticipants =
                await _context
                    .ConversationParticipants
                    .Where(x =>
                        x.UserId ==
                            user.Id)
                    .ToListAsync();

            foreach (var participant
                     in conversationParticipants)
            {
                participant.IsActive =
                    false;

                participant.LastReadAtUtc =
                    null;
            }

            if (client != null)
            {
                var reviews =
                    await _context.Reviews
                        .Where(x =>
                            x.ClientId ==
                                client.Id)
                        .ToListAsync();

                foreach (var review
                         in reviews)
                {
                    review.Comment =
                        string.Empty;
                }
            }

            if (client != null)
            {
                var activeMemberships =
                    await _context
                        .ClientMemberships
                        .Where(x =>
                            x.ClientId ==
                                client.Id &&
                            x.IsActive)
                        .ToListAsync();

                foreach (var membership
                         in activeMemberships)
                {
                    membership.IsActive =
                        false;

                    membership.RemainingSessions =
                        0;

                    membership.UpdatedAtUtc =
                        now;
                }
            }

            /*
             * 11. THERAPIST PROFILE
             */
            if (therapist != null)
            {
                therapist.Biography =
                    string.Empty;

                therapist.Specialization =
                    "Deleted account";

                therapist.SpecializationId =
                    null;

                therapist.VerificationNotes =
                    null;

                therapist.ProfileImagePath =
                    null;

                therapist.Location =
                    null;

                therapist.Country =
                    string.Empty;

                therapist.City =
                    string.Empty;

                therapist.Address =
                    string.Empty;

                therapist.Latitude =
                    null;

                therapist.Longitude =
                    null;

                therapist.OffersOnline =
                    false;

                therapist.OffersInPerson =
                    false;

                therapist.Languages =
                    null;

                therapist.Education =
                    string.Empty;

                therapist.IsDeleted =
                    true;

                therapist.UpdatedAtUtc =
                    now;

                var therapistApproaches =
                    await _context
                        .TherapistTherapyApproaches
                        .Where(x =>
                            x.TherapistId ==
                                therapist.Id)
                        .ToListAsync();

                _context
                    .TherapistTherapyApproaches
                    .RemoveRange(
                        therapistApproaches);

                var availabilities =
                    await _context
                        .TherapistAvailabilities
                        .Where(x =>
                            x.TherapistId ==
                                therapist.Id)
                        .ToListAsync();

                _context
                    .TherapistAvailabilities
                    .RemoveRange(
                        availabilities);

                var unavailableDates =
                    await _context
                        .TherapistUnavailableDates
                        .Where(x =>
                            x.TherapistId ==
                                therapist.Id)
                        .ToListAsync();

                _context
                    .TherapistUnavailableDates
                    .RemoveRange(
                        unavailableDates);
            }

            /*
             * 12. ANONYMIZE IDENTITY
             */
            var anonymizedEmail =
                $"deleted-{user.Id}-"
                + $"{Guid.NewGuid():N}"
                + "@deleted.mindbloom.invalid";

            var anonymizedUsername =
                $"deleted-user-{user.Id}-"
                + Guid.NewGuid()
                    .ToString("N");

            user.FirstName =
                "Deleted";

            user.LastName =
                "User";

            user.Email =
                anonymizedEmail;

            user.NormalizedEmail =
                anonymizedEmail
                    .ToUpperInvariant();

            user.UserName =
                anonymizedUsername;

            user.NormalizedUserName =
                anonymizedUsername
                    .ToUpperInvariant();

            user.PhoneNumber =
                null;

            user.ProfileImageUrl =
                null;

            user.Gender =
                null;

            user.DateOfBirth =
                DateTime.UnixEpoch;

            user.EmailConfirmed =
                false;

            user.IsEmailVerified =
                false;

            user.TwoFactorEnabled =
                false;

            user.TwoFactorEnabledCustom =
                false;

            user.IsActive =
                false;

            user.IsBlocked =
                true;

            user.LastLoginAtUtc =
                null;

            user.SecurityStamp =
                Guid.NewGuid()
                    .ToString("N");

                    await _context
             .SaveChangesAsync();

                    await transaction
                        .CommitAsync();
                }
                catch
                {
                    await transaction
                        .RollbackAsync();

                    throw;
                }
            });

        await _securityAuditService
            .WriteAsync(
                new SecurityAuditWriteDto
                {
                    UserId =
                        null,

                    EventType =
                        "AccountDeleted",

                    IsSuccessful =
                        true,

                    FailureReason =
                        null,

                    ResourceType =
                        "Account",

                    ResourceId =
                        null
                });
    }

    public async Task<Login2FAResponseDto>
     LoginWith2FAAsync(
         LoginRequestDto request)
    {
        var normalizedEmail =
            request.Email
                .Trim()
                .ToLowerInvariant();

        var user =
            await _userManager
                .FindByEmailAsync(
                    normalizedEmail);

        if (user == null)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId = null,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "InvalidCredentials",

                        ResourceType =
                            "Authentication"
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (user.IsBlocked ||
            !user.IsActive)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            user.IsBlocked
                                ? "AccountBlocked"
                                : "AccountInactive",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (await _userManager
        .IsLockedOutAsync(
            user))
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "AccountTemporarilyLocked",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (!user.IsEmailVerified &&
            !IsDemoAccount(
                user.Email!))
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "EmailNotVerified",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Email is not verified.");
        }

        var isPasswordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.Password);
        if (!isPasswordValid)
        {
            var accessFailedResult =
                await _userManager
                    .AccessFailedAsync(
                        user);

            if (!accessFailedResult.Succeeded)
            {
                throw new UnauthorizedException(
                    "Invalid credentials.");
            }

            var isNowLockedOut =
                await _userManager
                    .IsLockedOutAsync(
                        user);

            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            isNowLockedOut
                                ? "AccountTemporarilyLocked"
                                : "LoginFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            isNowLockedOut
                                ? "MaximumFailedLoginAttemptsExceeded"
                                : "InvalidCredentials",

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            user.Id.ToString()
                    });

           throw new UnauthorizedException(
                "Invalid credentials.");
        }

        if (!user.TwoFactorEnabledCustom ||
            IsDemoAccount(
                user.Email!))
        {
            var authResponse =
                await LoginAsync(
                    request);

            return new Login2FAResponseDto
            {
                RequiresTwoFactor =
                    false,

                Message =
                    "Login successful.",

                ChallengeToken =
                    null,

                ChallengeExpiresAtUtc =
                    null,

                Auth =
                    authResponse
            };
        }

        var now =
            DateTime.UtcNow;

        var previousChallenges =
            await _context
                .TwoFactorLoginChallenges
                .Where(x =>
                    x.UserId == user.Id &&
                    !x.IsUsed &&
                    !x.IsDeleted)
                .ToListAsync();

        foreach (var previousChallenge
                 in previousChallenges)
        {
            previousChallenge.IsUsed =
                true;

            previousChallenge.UsedAtUtc =
                now;
        }

        var code =
            RandomNumberGenerator
                .GetInt32(
                    100000,
                    1000000)
                .ToString();

        var codeHash =
            _userManager.PasswordHasher
                .HashPassword(
                    user,
                    code);

        var challengeBytes =
            RandomNumberGenerator
                .GetBytes(32);

        var challengeToken =
            WebEncoders
                .Base64UrlEncode(
                    challengeBytes);

        var challengeHash =
            HashTwoFactorChallenge(
                challengeToken);

        var expiresAtUtc =
            now.AddMinutes(5);

        var challenge =
            new TwoFactorLoginChallenge
            {
                UserId =
                    user.Id,

                ChallengeHash =
                    challengeHash,

                CodeHash =
                    codeHash,

                IssuedAtUtc =
                    now,

                ExpiresAtUtc =
                    expiresAtUtc,

                FailedAttempts =
                    0,

                MaximumAttempts =
                    5,

                IsUsed =
                    false,

                UsedAtUtc =
                    null,

                LockedAtUtc =
                    null,

                RememberMe =
                    request.RememberMe
            };

        _context
            .TwoFactorLoginChallenges
            .Add(
                challenge);

        _context.UserAudits.Add(
            new UserAudit
            {
                TargetUserId =
                    user.Id,

                ChangedByUserId =
                    user.Id,

                Action =
                    "TwoFactorLoginChallengeCreated",

                PreviousValues =
                    null,

                NewValues =
                    null,

                Reason =
                    "Two-factor authentication challenge created.",

                ChangedAtUtc =
                    now
            });

        await _context
            .SaveChangesAsync();

        await _securityAuditService
    .WriteAsync(
        new SecurityAuditWriteDto
        {
            UserId =
                user.Id,

            EventType =
                "TwoFactorChallengeIssued",

            IsSuccessful =
                true,

            FailureReason =
                null,

            ResourceType =
                "Authentication",

            ResourceId =
                user.Id.ToString()
        });

        var emailMessage =
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
             "Your MindBloom verification code is: "
             + code
             + Environment.NewLine
             + Environment.NewLine
             + "This code expires in 5 minutes.",

         IsHtml =
             false,

         Source =
             "MindBloom.API"
     };

        try
        {
            await _notificationPublisher
                .PublishEmailAsync(emailMessage)
                .WaitAsync(
                    TimeSpan.FromSeconds(5));
        }
        catch (TimeoutException)
        {
            throw new InvalidOperationException(
                "Two-factor authentication code could not be queued for delivery.");
        }

        return new Login2FAResponseDto
        {
            RequiresTwoFactor =
                true,

            Message =
                "A verification code has been sent to your email.",

            ChallengeToken =
                challengeToken,

            ChallengeExpiresAtUtc =
                expiresAtUtc,

            Auth =
                null
        };
    }

    public async Task<AuthResponseDto>
     Verify2FAAsync(
         Verify2FADto request)
    {
        const string safeErrorMessage =
            "Two-factor authentication verification failed.";

        if (string.IsNullOrWhiteSpace(
                request.ChallengeToken))
        {
            throw new UnauthorizedException(
                safeErrorMessage);
        }

        var challengeHash =
            HashTwoFactorChallenge(
                request.ChallengeToken);

        var challenge =
            await _context
                .TwoFactorLoginChallenges
                .Include(x =>
                    x.User)
                .FirstOrDefaultAsync(x =>
                    x.ChallengeHash ==
                        challengeHash &&
                    !x.IsDeleted);

        if (challenge == null)
        {
            throw new UnauthorizedException(
                safeErrorMessage);
        }

        var now =
            DateTime.UtcNow;

        if (challenge.IsUsed)
        {
            throw new UnauthorizedException(
                safeErrorMessage);
        }

        if (challenge.LockedAtUtc
            .HasValue)
        {
            throw new UnauthorizedException(
                safeErrorMessage);
        }

        if (challenge.ExpiresAtUtc <=
            now)
        {
            challenge.IsUsed =
                true;

            challenge.UsedAtUtc =
                now;

            _context.UserAudits.Add(
                new UserAudit
                {
                    TargetUserId =
                        challenge.UserId,

                    ChangedByUserId =
                        challenge.UserId,

                    Action =
                        "TwoFactorVerificationExpired",

                    PreviousValues =
                        null,

                    NewValues =
                        null,

                    Reason =
                        "Expired two-factor authentication challenge.",

                    ChangedAtUtc =
                        now
                });

            await _context
                .SaveChangesAsync();

            await _securityAuditService
    .WriteAsync(
        new SecurityAuditWriteDto
        {
            UserId =
                challenge.UserId,

            EventType =
                "TwoFactorVerificationFailed",

            IsSuccessful =
                false,

            FailureReason =
                "ChallengeExpired",

            ResourceType =
                "Authentication",

            ResourceId =
                challenge.UserId.ToString()
        });

            throw new UnauthorizedException(
                safeErrorMessage);
        }

        var user =
            challenge.User;

        if (user.IsBlocked ||
            !user.IsActive ||
            !user.TwoFactorEnabledCustom)
        {
            challenge.IsUsed =
                true;

            challenge.UsedAtUtc =
                now;

            await _context
                .SaveChangesAsync();

            throw new UnauthorizedException(
                safeErrorMessage);
        }

        var verificationResult =
            _userManager
                .PasswordHasher
                .VerifyHashedPassword(
                    user,
                    challenge.CodeHash,
                    request.Code.Trim());

        if (verificationResult ==
            PasswordVerificationResult.Failed)
        {
            challenge.FailedAttempts++;

            if (challenge.FailedAttempts >=
                challenge.MaximumAttempts)
            {
                challenge.LockedAtUtc =
                    now;

                challenge.IsUsed =
                    true;

                challenge.UsedAtUtc =
                    now;
            }

            _context.UserAudits.Add(
                new UserAudit
                {
                    TargetUserId =
                        user.Id,

                    ChangedByUserId =
                        user.Id,

                    Action =
                        challenge.IsUsed
                            ? "TwoFactorVerificationLocked"
                            : "TwoFactorVerificationFailed",

                    PreviousValues =
                        null,

                    NewValues =
                        null,

                    Reason =
                        challenge.IsUsed
                            ? "Two-factor authentication challenge locked after too many failed attempts."
                            : "Two-factor authentication verification failed.",

                    ChangedAtUtc =
                        now
                });

            await _context
                .SaveChangesAsync();

            await _securityAuditService
    .WriteAsync(
        new SecurityAuditWriteDto
        {
            UserId =
                user.Id,

            EventType =
                challenge.IsUsed
                    ? "TwoFactorVerificationLocked"
                    : "TwoFactorVerificationFailed",

            IsSuccessful =
                false,

            FailureReason =
                challenge.IsUsed
                    ? "MaximumAttemptsExceeded"
                    : "InvalidVerificationCode",

            ResourceType =
                "Authentication",

            ResourceId =
                user.Id.ToString()
        });

            throw new UnauthorizedException(
                safeErrorMessage);
        }

        challenge.IsUsed =
            true;

        challenge.UsedAtUtc =
            now;

        if (user.AccessFailedCount > 0)
        {
            var resetFailedResult =
                await _userManager
                    .ResetAccessFailedCountAsync(
                        user);

            if (!resetFailedResult.Succeeded)
            {
                throw new InvalidOperationException(
                    "Login state could not be updated.");
            }
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

        var accessToken =
            await _jwtTokenService
                .GenerateTokenAsync(
                    user);

        var refreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

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
                    challenge.RememberMe
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

        _context.UserAudits.Add(
            new UserAudit
            {
                TargetUserId =
                    user.Id,

                ChangedByUserId =
                    user.Id,

                Action =
                    "TwoFactorVerificationSucceeded",

                PreviousValues =
                    null,

                NewValues =
                    null,

                Reason =
                    "Two-factor authentication completed successfully.",

                ChangedAtUtc =
                    now
            });

        await _context
            .SaveChangesAsync();

        await _securityAuditService
    .WriteAsync(
        new SecurityAuditWriteDto
        {
            UserId =
                user.Id,

            EventType =
                "TwoFactorVerificationSucceeded",

            IsSuccessful =
                true,

            FailureReason =
                null,

            ResourceType =
                "Authentication",

            ResourceId =
                user.Id.ToString()
        });

        await _securityAuditService
            .WriteAsync(
                new SecurityAuditWriteDto
                {
                    UserId =
                        user.Id,

                    EventType =
                        "LoginSucceeded",

                    IsSuccessful =
                        true,

                    FailureReason =
                        null,

                    ResourceType =
                        "Authentication",

                    ResourceId =
                        user.Id.ToString()
                });

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
                accessToken,

            RefreshToken =
                refreshToken,

            Role =
                roles.First()
        };
    }

    public async Task Enable2FAAsync(
     int userId,
     ChangeTwoFactorSettingDto request)
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

        if (!user.IsActive ||
            user.IsBlocked)
        {
            throw new UnauthorizedException(
                "Account is not available.");
        }

        var passwordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.CurrentPassword);

        if (!passwordValid)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "TwoFactorEnableFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "CurrentPasswordIncorrect",

                        ResourceType =
                            "AccountSecurity",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Current password is incorrect.");
        }

        if (user.TwoFactorEnabledCustom)
        {
            return;
        }

        var now =
            DateTime.UtcNow;

        user.TwoFactorEnabledCustom =
            true;

        var updateResult =
            await _userManager
                .UpdateAsync(
                    user);

        if (!updateResult.Succeeded)
        {
            throw new BadRequestException(
                "Two-factor authentication could not be enabled.");
        }

        _context.UserAudits.Add(
            new UserAudit
            {
                TargetUserId =
                    user.Id,

                ChangedByUserId =
                    user.Id,

                Action =
                    "TwoFactorEnabled",

                PreviousValues =
                    null,

                NewValues =
                    null,

                Reason =
                    "Two-factor authentication enabled by account owner.",

                ChangedAtUtc =
                    now
            });

        await _context
            .SaveChangesAsync();

        await _securityAuditService
    .WriteAsync(
        new SecurityAuditWriteDto
        {
            UserId =
                user.Id,

            EventType =
                "TwoFactorEnabled",

            IsSuccessful =
                true,

            FailureReason =
                null,

            ResourceType =
                "AccountSecurity",

            ResourceId =
                user.Id.ToString()
        });
    }

    public async Task Disable2FAAsync(
    int userId,
    ChangeTwoFactorSettingDto request)
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

        if (!user.IsActive ||
    user.IsBlocked)
        {
            throw new UnauthorizedException(
                "Account is not available.");
        }

        var passwordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.CurrentPassword);

        if (!passwordValid)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            user.Id,

                        EventType =
                            "TwoFactorDisableFailed",

                        IsSuccessful =
                            false,

                        FailureReason =
                            "CurrentPasswordIncorrect",

                        ResourceType =
                            "AccountSecurity",

                        ResourceId =
                            user.Id.ToString()
                    });

            throw new UnauthorizedException(
                "Current password is incorrect.");
        }

        if (!user.TwoFactorEnabledCustom)
        {
            return;
        }

        var now =
            DateTime.UtcNow;

        user.TwoFactorEnabledCustom =
            false;

        var activeChallenges =
            await _context
                .TwoFactorLoginChallenges
                .Where(x =>
                    x.UserId == user.Id &&
                    !x.IsUsed &&
                    !x.IsDeleted)
                .ToListAsync();

        foreach (var challenge
                 in activeChallenges)
        {
            challenge.IsUsed =
                true;

            challenge.UsedAtUtc =
                now;
        }

        var updateResult =
            await _userManager
                .UpdateAsync(
                    user);

        if (!updateResult.Succeeded)
        {
            throw new BadRequestException(
                "Two-factor authentication could not be disabled.");
        }

        _context.UserAudits.Add(
            new UserAudit
            {
                TargetUserId =
                    user.Id,

                ChangedByUserId =
                    user.Id,

                Action =
                    "TwoFactorDisabled",

                PreviousValues =
                    null,

                NewValues =
                    null,

                Reason =
                    "Two-factor authentication disabled by account owner.",

                ChangedAtUtc =
                    now
            });

        await _context
            .SaveChangesAsync();

        await _securityAuditService
    .WriteAsync(
        new SecurityAuditWriteDto
        {
            UserId =
                user.Id,

            EventType =
                "TwoFactorDisabled",

            IsSuccessful =
                true,

            FailureReason =
                null,

            ResourceType =
                "AccountSecurity",

            ResourceId =
                user.Id.ToString()
        });
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

        if (token == null ||
            token.RevokedAtUtc.HasValue)
        {
            await _securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            userId,

                        EventType =
                            "Logout",

                        IsSuccessful =
                            true,

                        ResourceType =
                            "Authentication",

                        ResourceId =
                            userId.ToString()
                    });

            return;
        }

        await RevokeSessionAsync(
            userId,
            token.SessionId,
            DateTime.UtcNow);

        await _securityAuditService
            .WriteAsync(
                new SecurityAuditWriteDto
                {
                    UserId =
                        userId,

                    EventType =
                        "Logout",

                    IsSuccessful =
                        true,

                    ResourceType =
                        "Authentication",

                    ResourceId =
                        userId.ToString()
                });
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

        await _securityAuditService
            .WriteAsync(
                new SecurityAuditWriteDto
                {
                    UserId =
                        userId,

                    EventType =
                        "LogoutAllSessions",

                    IsSuccessful =
                        true,

                    ResourceType =
                        "Authentication",

                    ResourceId =
                        userId.ToString()
                });
    }

    private static string HashPasswordResetToken(
    string token)
    {
        if (string.IsNullOrWhiteSpace(
                token))
        {
            throw new BadRequestException(
                "Password reset token is required.");
        }

        var bytes =
            Encoding.UTF8.GetBytes(
                token.Trim());

        var hash =
            SHA256.HashData(
                bytes);

        return Convert.ToHexString(
            hash);
    }

    private static string
    HashTwoFactorChallenge(
        string challengeToken)
    {
        if (string.IsNullOrWhiteSpace(
                challengeToken))
        {
            throw new UnauthorizedException(
                "Two-factor authentication verification failed.");
        }

        var bytes =
            Encoding.UTF8
                .GetBytes(
                    challengeToken.Trim());

        var hash =
            SHA256.HashData(
                bytes);

        return Convert
            .ToHexString(
                hash);
    }
}