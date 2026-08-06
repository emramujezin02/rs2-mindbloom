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

        services.AddIdentity<ApplicationUser, IdentityRole<int>>(options =>
        {
            options.Password.RequireDigit = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireUppercase = true;
            options.Password.RequireNonAlphanumeric = false;
            options.Password.RequiredLength = 6;
        })
        .AddEntityFrameworkStores<ApplicationDbContext>()
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

        services.Configure<JwtSettings>(options =>
        {
            options.SecretKey = jwtSettings.SecretKey;
            options.Issuer = jwtSettings.Issuer;
            options.Audience = jwtSettings.Audience;
            options.ExpirationInMinutes = jwtSettings.ExpirationInMinutes;
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

                                    return Task
                                        .CompletedTask;
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

        services.AddScoped<IJwtTokenService, JwtTokenService>();

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

        services.AddScoped<
    IFcmDeviceTokenService,
    FcmDeviceTokenService>();

        services.AddScoped<IUserSettingsService, UserSettingsService>();

        return services;
    }
}