using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using MindBloom.Infrastructure.Services;
using MindBloom.Infrastructure.BackgroundServices;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Application.Features.Favorites.Interfaces;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Application.Features.JournalEntries.Interfaces;
using MindBloom.Application.Features.Articles.Interfaces;
using MindBloom.Application.Features.Workshops.Interfaces;
using MindBloom.Infrastructure.Payments;
using MindBloom.Application.Features.Chat.Interfaces;
using MindBloom.Application.Features.ReferenceData.Interfaces;
using MindBloom.Application.Features.AdminReports.Interfaces;
using MindBloom.Infrastructure.Services.Geocoding;
using Microsoft.AspNetCore.Authorization;
using MindBloom.Domain.Enums;
using System.Security.Claims;
using MindBloom.Shared.Constants;
using MindBloom.Application.Features.Auth.Validators;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Application.Features.Privacy.Interfaces;
using MindBloom.Infrastructure.Configuration;

namespace MindBloom.Infrastructure.DependencyInjection;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString =
            Environment.GetEnvironmentVariable(
                "DB_CONNECTION");

        if (string.IsNullOrWhiteSpace(
                connectionString))
        {
            throw new InvalidOperationException(
                "The DB_CONNECTION environment variable is not configured.");
        }

        services.AddDbContext<ApplicationDbContext>(
            options =>
            {
                options.UseSqlServer(
                    connectionString,
                    sqlServerOptions =>
                    {
                        sqlServerOptions.EnableRetryOnFailure(
                            maxRetryCount: 5,
                            maxRetryDelay:
                                TimeSpan.FromSeconds(10),
                            errorNumbersToAdd: null);
                    });
            });

        services.AddSignalR();

        var accountLockoutSettings =
    configuration
        .GetSection(
            AccountLockoutSettings
                .SectionName)
        .Get<AccountLockoutSettings>();

        if (accountLockoutSettings == null)
        {
            throw new InvalidOperationException(
                "AccountLockout configuration is required.");
        }

        if (accountLockoutSettings
                .MaxFailedAccessAttempts <= 0)
        {
            throw new InvalidOperationException(
                "AccountLockout:MaxFailedAccessAttempts must be greater than 0.");
        }

        if (accountLockoutSettings
                .LockoutMinutes <= 0)
        {
            throw new InvalidOperationException(
                "AccountLockout:LockoutMinutes must be greater than 0.");
        }

        services.Configure<
            AccountLockoutSettings>(
            configuration.GetSection(
                AccountLockoutSettings
                    .SectionName));

        services
    .AddOptions<UploadSettings>()
    .Configure(options =>
    {
        options.MaximumImageSizeMb =
            GetPositiveInt(
                configuration,
                "UPLOAD_MAX_IMAGE_SIZE_MB",
                5);

        options.MaximumDocumentSizeMb =
            GetPositiveInt(
                configuration,
                "UPLOAD_MAX_DOCUMENT_SIZE_MB",
                10);

        options.RootFolder =
            configuration[
                "UPLOAD_ROOT_PATH"]?
                .Trim()
            ?? "uploads";
    })
    .Validate(
        options =>
            options.MaximumImageSizeMb > 0,
        "UPLOAD_MAX_IMAGE_SIZE_MB must be greater than zero.")
    .Validate(
        options =>
            options.MaximumDocumentSizeMb > 0,
        "UPLOAD_MAX_DOCUMENT_SIZE_MB must be greater than zero.")
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.RootFolder),
        "UPLOAD_ROOT_PATH is required.")
    .ValidateOnStart();

        services
            .AddIdentity<
                ApplicationUser,
                IdentityRole<int>>(
                options =>
                {
                    options.Password
                        .RequireDigit =
                        true;

                    options.Password
                        .RequireLowercase =
                        true;

                    options.Password
                        .RequireUppercase =
                        true;

                    options.Password
                        .RequireNonAlphanumeric =
                        true;

                    options.Password
                        .RequiredLength =
                        AuthValidationRules
                            .MinimumPasswordLength;

                    options.Password
                        .RequiredUniqueChars =
                        4;

                    options.User
                        .RequireUniqueEmail =
                        true;

                    options.SignIn
                        .RequireConfirmedEmail =
                        false;

                    options.Lockout
    .AllowedForNewUsers =
    true;

                    options.Lockout
                        .MaxFailedAccessAttempts =
                        accountLockoutSettings
                            .MaxFailedAccessAttempts;

                    options.Lockout
                        .DefaultLockoutTimeSpan =
                        TimeSpan.FromMinutes(
                            accountLockoutSettings
                                .LockoutMinutes);
                })
            .AddEntityFrameworkStores<
                ApplicationDbContext>()
            .AddDefaultTokenProviders();

        var jwtSecret =
            Environment.GetEnvironmentVariable(
                "JWT_SECRET");

        var jwtIssuer =
            Environment.GetEnvironmentVariable(
                "JWT_ISSUER");

        var jwtAudience =
            Environment.GetEnvironmentVariable(
                "JWT_AUDIENCE");

        var jwtExpirationValue =
            Environment.GetEnvironmentVariable(
                "JWT_EXPIRATION_MINUTES");

        if (string.IsNullOrWhiteSpace(
                jwtSecret))
        {
            throw new InvalidOperationException(
                "Environment variable 'JWT_SECRET' is required.");
        }

        if (Encoding.UTF8.GetByteCount(
                jwtSecret) <
            JwtSettings.MinimumSecretLength)
        {
            throw new InvalidOperationException(
                $"JWT_SECRET must contain at least "
                + $"{JwtSettings.MinimumSecretLength} bytes.");
        }

        var forbiddenJwtSecrets =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
        "secret",
        "jwt-secret",
        "changeme",
        "change-me",
        "your-secret-key",
        "your-jwt-secret",
        "your-super-secret-key"
            };

        if (forbiddenJwtSecrets.Contains(
                jwtSecret.Trim()))
        {
            throw new InvalidOperationException(
                "JWT_SECRET uses an unsafe default/example value.");
        }

        if (string.IsNullOrWhiteSpace(
                jwtIssuer))
        {
            throw new InvalidOperationException(
                "Environment variable 'JWT_ISSUER' is required.");
        }

        if (string.IsNullOrWhiteSpace(
                jwtAudience))
        {
            throw new InvalidOperationException(
                "Environment variable 'JWT_AUDIENCE' is required.");
        }

        if (!int.TryParse(
                jwtExpirationValue,
                out var jwtExpirationMinutes))
        {
            throw new InvalidOperationException(
                "Environment variable "
                + "'JWT_EXPIRATION_MINUTES' "
                + "must be a valid integer.");
        }

        if (jwtExpirationMinutes <
                JwtSettings
                    .MinimumExpirationMinutes ||
            jwtExpirationMinutes >
                JwtSettings
                    .MaximumExpirationMinutes)
        {
            throw new InvalidOperationException(
                "JWT_EXPIRATION_MINUTES must be "
                + $"between "
                + $"{JwtSettings.MinimumExpirationMinutes} "
                + $"and "
                + $"{JwtSettings.MaximumExpirationMinutes}.");
        }

        var jwtSettings =
            new JwtSettings
            {
                SecretKey =
                    jwtSecret,

                Issuer =
                    jwtIssuer.Trim(),

                Audience =
                    jwtAudience.Trim(),

                ExpirationInMinutes =
                    jwtExpirationMinutes
            };

        services.Configure<JwtSettings>(
            options =>
            {
                options.SecretKey =
                    jwtSettings.SecretKey;

                options.Issuer =
                    jwtSettings.Issuer;

                options.Audience =
                    jwtSettings.Audience;

                options.ExpirationInMinutes =
                    jwtSettings
                        .ExpirationInMinutes;
            });


        services.AddHttpClient<IGeocodingService, GoogleGeocodingService>(client =>
        {
            client.BaseAddress =
                new Uri("https://maps.googleapis.com/maps/api/geocode/");

            client.Timeout = TimeSpan.FromSeconds(10);
        });

        var environmentName =
    Environment.GetEnvironmentVariable(
        "ASPNETCORE_ENVIRONMENT")
    ??
    Environment.GetEnvironmentVariable(
        "DOTNET_ENVIRONMENT")
    ??
    "Production";

        var isDevelopment =
            string.Equals(
                environmentName,
                "Development",
                StringComparison.OrdinalIgnoreCase);

        var key =
      Encoding.UTF8.GetBytes(
          jwtSettings.SecretKey);

        services.AddAuthentication(
            options =>
            {
                options.DefaultAuthenticateScheme =
                    JwtBearerDefaults
                        .AuthenticationScheme;

                options.DefaultChallengeScheme =
                    JwtBearerDefaults
                        .AuthenticationScheme;
            })
            .AddJwtBearer(
                options =>
                {
                    options.RequireHttpsMetadata =
                        !isDevelopment;

                    options.SaveToken =
                        false;

                    options.TokenValidationParameters =
                        new TokenValidationParameters
                        {
                            ValidateIssuer =
                                true,

                            ValidateAudience =
                                true,

                            ValidateLifetime =
                                true,

                            ValidateIssuerSigningKey =
                                true,

                            RequireExpirationTime =
                                true,

                            RequireSignedTokens =
                                true,

                            ValidIssuer =
                                jwtSettings.Issuer,

                            ValidAudience =
                                jwtSettings.Audience,

                            IssuerSigningKey =
                                new SymmetricSecurityKey(
                                    key),

                            ClockSkew =
                                TimeSpan.FromSeconds(
                                    30),

                            NameClaimType =
                                ClaimTypes
                                    .NameIdentifier,

                            RoleClaimType =
                                ClaimTypes.Role
                        };

                    options.Events =
    new JwtBearerEvents
    {
        OnMessageReceived =
            context =>
            {
                var accessToken =
                    context.Request
                        .Query[
                            "access_token"]
                        .FirstOrDefault();

                var requestPath =
                    context
                        .HttpContext
                        .Request
                        .Path;

                var isSignalRHub =
                    requestPath
                        .StartsWithSegments(
                            "/hubs/notifications")
                    ||
                    requestPath
                        .StartsWithSegments(
                            "/hubs/chat");

                if (!string
                        .IsNullOrWhiteSpace(
                            accessToken) &&
                    isSignalRHub)
                {
                    context.Token =
                        accessToken;
                }

                return Task.CompletedTask;
            },

        OnTokenValidated =
            async context =>
            {
                var userIdValue =
                    context.Principal?
                        .FindFirst(
                            ClaimTypes
                                .NameIdentifier)?
                        .Value;

                if (!int.TryParse(
                        userIdValue,
                        out var userId))
                {
                    context.Fail(
                        "Invalid authenticated user.");

                    return;
                }

                var dbContext =
                    context.HttpContext
                        .RequestServices
                        .GetRequiredService<
                            ApplicationDbContext>();

                var userState =
                    await dbContext.Users
                        .AsNoTracking()
                        .Where(user =>
                            user.Id == userId)
                        .Select(user =>
                            new
                            {
                                user.IsActive,
                                user.IsBlocked
                            })
                        .FirstOrDefaultAsync();

                if (userState == null ||
                    !userState.IsActive ||
                    userState.IsBlocked)
                {
                    context.Fail(
                        "User session is no longer valid.");
                }
            }
    };
                });

        services.AddAuthorization(options =>
        {
            options.FallbackPolicy =
                new AuthorizationPolicyBuilder(
                        JwtBearerDefaults
                            .AuthenticationScheme)
                    .RequireAuthenticatedUser()
                    .Build();

            options.AddPolicy(
                AuthorizationPolicyConstants.ClientOnly,
                policy =>
                {
                    policy.RequireAuthenticatedUser();

                    policy.RequireRole(
                        RoleConstants.Client);
                });

            options.AddPolicy(
                AuthorizationPolicyConstants.TherapistOnly,
                policy =>
                {
                    policy.RequireAuthenticatedUser();

                    policy.RequireRole(
                        RoleConstants.Therapist);
                });

            options.AddPolicy(
                AuthorizationPolicyConstants.AdminOnly,
                policy =>
                {
                    policy.RequireAuthenticatedUser();

                    policy.RequireRole(
                        RoleConstants.Admin);
                });

            options.AddPolicy(
                AuthorizationPolicyConstants.ClientOrTherapist,
                policy =>
                {
                    policy.RequireAuthenticatedUser();

                    policy.RequireRole(
                        RoleConstants.Client,
                        RoleConstants.Therapist);
                });

            options.AddPolicy(
                AuthorizationPolicyConstants.AdminOrTherapist,
                policy =>
                {
                    policy.RequireAuthenticatedUser();

                    policy.RequireRole(
                        RoleConstants.Admin,
                        RoleConstants.Therapist);
                });

            options.AddPolicy(
                AuthorizationPolicyConstants.AuthenticatedUser,
                policy =>
                {
                    policy.RequireAuthenticatedUser();
                });
        });

        var stripeSecretKey =
    Environment.GetEnvironmentVariable(
        "STRIPE_SECRET_KEY");

        var stripeWebhookSecret =
            Environment.GetEnvironmentVariable(
                "STRIPE_WEBHOOK_SECRET");

        if (string.IsNullOrWhiteSpace(
                stripeSecretKey))
        {
            throw new InvalidOperationException(
                "Environment variable "
                + "'STRIPE_SECRET_KEY' "
                + "is required.");
        }

        if (string.IsNullOrWhiteSpace(
                stripeWebhookSecret))
        {
            throw new InvalidOperationException(
                "Environment variable "
                + "'STRIPE_WEBHOOK_SECRET' "
                + "is required.");
        }

        services.Configure<StripeSettings>(
            options =>
            {
                options.SecretKey =
                    stripeSecretKey.Trim();

                options.WebhookSecret =
                    stripeWebhookSecret.Trim();

                options.Currency =
                    "usd";
            });

        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<
    StripeWebhookService>();

        services.AddScoped<
    IPrivacyConsentService,
    PrivacyConsentService>();

        services.AddScoped<IAuthService, AuthService>();

        services.AddScoped<ITherapistService, TherapistService>();
        services.AddScoped<IReferenceDataService, ReferenceDataService>();

        services.AddScoped<IAppointmentService, AppointmentService>();

        services.AddScoped<IReviewService, ReviewService>();

        services.AddScoped<IPaymentService, PaymentService>();

        services.AddScoped<INotificationService,NotificationService>();

        services.AddScoped<INotificationSender,SignalRNotificationSender>();

        services.AddScoped<IFavoriteService, FavoriteService>();

        services.AddScoped<IEmailService, EmailService>();

        services.AddHostedService<AppointmentReminderService>();

        services.AddScoped<IAdminService,AdminService>();

        services.AddScoped<IMembershipService, MembershipService>();

        services.AddScoped<IUserProfileService, UserProfileService>();

        services.AddScoped<IJournalEntryService,JournalEntryService>();

        services.AddScoped<IArticleService,ArticleService>();

        services.AddScoped<IWorkshopService, WorkshopService>();

        services.AddScoped<StripeVerificationService>();
        services.AddScoped<IChatService,ChatService>();

        services.AddScoped<IBusinessNotificationService, BusinessNotificationService>();

        services.AddScoped<IAdminReportService, AdminReportService>();

        services.AddScoped<
    IAdminAuditService,
    AdminAuditService>();

        services.AddScoped<
    ITherapistClientAccessService,
    TherapistClientAccessService>();

        services.AddSingleton<
    IChatMessageRateLimiter,
    ChatMessageRateLimiter>();

        services.AddHttpContextAccessor();

        services.AddScoped<
            ISecurityAuditService,
            SecurityAuditService>();

        services.AddScoped<
    IFcmDeviceTokenService,
    FcmDeviceTokenService>();

        services.AddScoped<IUserSettingsService, UserSettingsService>();

        return services;
    }

    private static int GetPositiveInt(
    IConfiguration configuration,
    string key,
    int defaultValue)
    {
        var value =
            configuration[key];

        if (string.IsNullOrWhiteSpace(
                value))
        {
            return defaultValue;
        }

        if (!int.TryParse(
                value,
                out var parsedValue) ||
            parsedValue <= 0)
        {
            throw new InvalidOperationException(
                $"Environment variable '{key}' "
                + "must be a positive integer.");
        }

        return parsedValue;
    }
}