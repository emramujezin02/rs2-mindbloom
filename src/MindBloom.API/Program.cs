using System.Text.Json;
using DotNetEnv;
using FluentValidation;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi.Models;
using MindBloom.API.Configuration;
using MindBloom.API.Filters;
using MindBloom.API.Messaging.DependencyInjection;
using MindBloom.API.Middlewares;
using MindBloom.API.Models;
using MindBloom.Application.Features.Auth.Validators;
using MindBloom.Application.Recommendations.Services;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.DependencyInjection;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Realtime;
using MindBloom.Infrastructure.Recommendations;
using MindBloom.Application.Features.PrivateJournalEntries.Interfaces;
using MindBloom.Infrastructure.Services;
using MindBloom.Application.Features.PrivateJournalEntries.Validators;
using MindBloom.Application.Features.ClientOnboarding.Interfaces;
using MindBloom.Application.Features.ClientOnboarding.Validators;
using MindBloom.Application.Features.Users.Interfaces;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using MindBloom.Shared.Constants;
using System.Security.Claims;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using MindBloom.API.Health;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Persistence.Migration;

var bootstrapEnvironment =
    Environment.GetEnvironmentVariable(
        "ASPNETCORE_ENVIRONMENT")
    ??
    Environment.GetEnvironmentVariable(
        "DOTNET_ENVIRONMENT");

if (!string.Equals(
        bootstrapEnvironment,
        "Testing",
        StringComparison.OrdinalIgnoreCase))
{
    Env.TraversePath()
        .Load();
}

var builder =
    WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(
    options =>
    {
        options.AddServerHeader =
            false;
    });

builder.Services
    .AddOptions<CorsSettings>()
    .Bind(
        builder.Configuration.GetSection(
            CorsSettings.SectionName))
    .ValidateOnStart();

builder.Services.AddSingleton<
    IValidateOptions<CorsSettings>,
    CorsSettingsValidator>();

builder.Configuration
    .AddEnvironmentVariables();

if (!builder.Environment
        .IsEnvironment(
            "Testing"))
{
    EnvironmentConfigurationValidator
        .ValidateApi(
            builder.Configuration);
}

builder.Services.Configure<RequestTimingOptions>(
    builder.Configuration.GetSection(
        RequestTimingOptions.SectionName));

builder.Services
    .AddValidatorsFromAssemblyContaining<
        RegisterRequestDtoValidator>();

builder.Services
    .AddValidatorsFromAssemblyContaining<
        SaveClientOnboardingDtoValidator>();

builder.Services
    .AddScoped<FluentValidationFilter>();

builder.Services
    .AddScoped<
        IPrivateJournalEntryService,
        PrivateJournalEntryService>();

builder.Services
    .AddValidatorsFromAssemblyContaining<
        CreatePrivateJournalEntryDtoValidator>();

builder.Services.AddScoped<
    IUserSettingsService,
    UserSettingsService>();

builder.Services
    .AddControllers(options =>
    {
        options.Filters.AddService<
            FluentValidationFilter>();
    })
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory =
            context =>
            {
                var errors =
                    context.ModelState
                        .Where(item =>
                            item.Value?.Errors.Count > 0)
                        .ToDictionary(
                            item =>
                                ToCamelCase(
                                    item.Key),
                            item =>
                                item.Value!.Errors
                                    .Select(error =>
                                        string.IsNullOrWhiteSpace(
                                            error.ErrorMessage)
                                            ? "The provided value is invalid."
                                            : error.ErrorMessage)
                                    .Distinct()
                                    .ToArray(),
                            StringComparer.OrdinalIgnoreCase);

                return new BadRequestObjectResult(
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status400BadRequest,

                        Title =
                            "Validation failed",

                        Detail =
                            "One or more validation errors occurred.",

                        ValidationErrors =
                            errors
                    });
            };
    });

builder.Services
    .AddHealthChecks()

    .AddCheck<DatabaseHealthCheck>(
        name:
            "database",
        failureStatus:
            HealthStatus.Unhealthy,
        tags:
            new[]
            {
                "ready",
                "database"
            })

    .AddCheck<RabbitMqHealthCheck>(
        name:
            "rabbitmq",
        failureStatus:
            HealthStatus.Unhealthy,
        tags:
            new[]
            {
                "ready",
                "rabbitmq"
            });

builder.Services
    .AddNotificationMessaging(
        builder.Configuration);

builder.Services
    .AddEndpointsApiExplorer();

builder.Services
    .AddInfrastructure(
        builder.Configuration);

builder.Services
    .AddScoped<
        IRecommendationService,
        RecommendationService>();

builder.Services
    .AddScoped<
        IClientOnboardingService,
        ClientOnboardingService>();

var corsSettings =
    builder.Configuration
        .GetSection(
            CorsSettings.SectionName)
        .Get<CorsSettings>()
    ?? new CorsSettings();

builder.Services.AddCors(
    options =>
    {
        options.AddPolicy(
            CorsPolicyConstants
                .MindBloomClients,
            policy =>
            {
                var allowedOrigins =
                    corsSettings
                        .AllowedOrigins
                        .Where(origin =>
                            !string.IsNullOrWhiteSpace(
                                origin))
                        .Select(origin =>
                            origin.Trim())
                        .Distinct(
                            StringComparer
                                .OrdinalIgnoreCase)
                        .ToArray();

                if (allowedOrigins.Length >
                    0)
                {
                    policy.WithOrigins(
                        allowedOrigins);
                }

                policy.WithMethods(
                    corsSettings
                        .AllowedMethods);

                policy.WithHeaders(
                    corsSettings
                        .AllowedHeaders);
            });
    });

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc(
        "v1",
        new OpenApiInfo
        {
            Title = "MindBloom API",
            Version = "v1"
        });

    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type =
                SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In =
                ParameterLocation.Header,
            Description =
                "Enter JWT access token."
        });

    options.AddSecurityRequirement(
        new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference =
                        new OpenApiReference
                        {
                            Type =
                                ReferenceType
                                    .SecurityScheme,
                            Id = "Bearer"
                        }
                },
                Array.Empty<string>()
            }
        });
});

var rateLimitExceededEvent =
    new EventId(
        1200,
        "RateLimitExceeded");

var rateLimiting =
    builder.Configuration
        .GetSection(
            RateLimitingOptions.SectionName)
        .Get<RateLimitingOptions>()
    ?? new RateLimitingOptions();

builder.Services.AddRateLimiter(
    options =>
    {
        options.RejectionStatusCode =
            StatusCodes.Status429TooManyRequests;

        options.OnRejected =
            async (
                rejectedContext,
                cancellationToken) =>
            {
                var httpContext =
                    rejectedContext.HttpContext;

                var retryAfter =
                    TimeSpan.FromSeconds(60);

                if (rejectedContext.Lease
                    .TryGetMetadata(
                        MetadataName.RetryAfter,
                        out var metadataRetryAfter))
                {
                    retryAfter =
                        metadataRetryAfter;
                }

                var retryAfterSeconds =
                    Math.Max(
                        1,
                        (int)Math.Ceiling(
                            retryAfter.TotalSeconds));

                httpContext.Response.StatusCode =
                    StatusCodes
                        .Status429TooManyRequests;

                httpContext.Response.Headers
                    .RetryAfter =
                    retryAfterSeconds.ToString();

                httpContext.Response.ContentType =
                    "application/problem+json";

                var loggerFactory =
                    httpContext.RequestServices
                        .GetRequiredService<
                            ILoggerFactory>();

                var logger =
                    loggerFactory.CreateLogger(
                        "RateLimiting");

                var userId =
                    httpContext.User
                        .FindFirst(
                            ClaimTypes
                                .NameIdentifier)?
                        .Value;

                logger.LogWarning(
                    rateLimitExceededEvent,
                    "Rate limit exceeded. Method: {RequestMethod}, Path: {RequestPath}, UserId: {UserId}, RemoteIp: {RemoteIp}, RetryAfterSeconds: {RetryAfterSeconds}, Module: {Module}, Environment: {Environment}.",
                    httpContext.Request.Method,
                    httpContext.Request.Path.Value
                        ?? string.Empty,
                    string.IsNullOrWhiteSpace(
                        userId)
                        ? "anonymous"
                        : userId,
                    httpContext.Connection
                        .RemoteIpAddress?
                        .ToString()
                        ?? "unknown",
                    retryAfterSeconds,
                    "RateLimiting",
                    builder.Environment
                        .EnvironmentName);

                var response =
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status429TooManyRequests,

                        Title =
                            "Too many requests",

                        Detail =
                            "Too many requests were received. Please try again later."
                    };

                await httpContext.Response
                    .WriteAsync(
                        JsonSerializer.Serialize(
                            response,
                            new JsonSerializerOptions
                            {
                                PropertyNamingPolicy =
                                    JsonNamingPolicy
                                        .CamelCase
                            }),
                        cancellationToken);
            };

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.Login,
            rateLimiting.Login);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.Registration,
            rateLimiting.Registration);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.ForgotPassword,
            rateLimiting.ForgotPassword);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.ResetPassword,
            rateLimiting.ResetPassword);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.TwoFactorLogin,
            rateLimiting.TwoFactorLogin);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.TwoFactorVerify,
            rateLimiting.TwoFactorVerify);

        AddUserPolicy(
            options,
            RateLimitPolicyConstants.TwoFactorSettings,
            rateLimiting.TwoFactorSettings);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.RefreshToken,
            rateLimiting.RefreshToken);

        AddUserPolicy(
            options,
            RateLimitPolicyConstants.ChatMessages,
            rateLimiting.ChatMessages);

        AddUserPolicy(
            options,
            RateLimitPolicyConstants.Uploads,
            rateLimiting.Uploads);

        AddUserPolicy(
            options,
            RateLimitPolicyConstants.Recommendations,
            rateLimiting.Recommendations);

        AddIpPolicy(
            options,
            RateLimitPolicyConstants.PublicSearch,
            rateLimiting.PublicSearch);
    });

builder.Services.AddHsts(
    options =>
    {
        options.Preload =
            true;

        options.IncludeSubDomains =
            true;

        options.MaxAge =
            TimeSpan.FromDays(
                365);
    });

var app = builder.Build();

if (app.Environment.IsProduction())
{
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseMiddleware<
    SecurityHeadersMiddleware>();

app.UseMiddleware<
    CorrelationIdMiddleware>();

app.UseMiddleware<
    RequestTimingMiddleware>();

app.UseMiddleware<
    AdminAuditMiddleware>();

app.UseMiddleware<
    GlobalExceptionMiddleware>();

app.UseStatusCodePages(
    async statusCodeContext =>
    {
        var response =
            statusCodeContext
                .HttpContext
                .Response;

        if (response.HasStarted ||
            response.ContentLength.HasValue ||
            !string.IsNullOrWhiteSpace(
                response.ContentType))
        {
            return;
        }

        var error =
            response.StatusCode switch
            {
                StatusCodes.Status400BadRequest =>
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status400BadRequest,
                        Title = "Bad request",
                        Detail =
                            "The request is invalid."
                    },

                StatusCodes.Status401Unauthorized =>
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status401Unauthorized,
                        Title = "Unauthorized",
                        Detail =
                            "Authentication is required."
                    },

                StatusCodes.Status403Forbidden =>
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status403Forbidden,
                        Title = "Forbidden",
                        Detail =
                            "You do not have permission to access this resource."
                    },

                StatusCodes.Status404NotFound =>
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status404NotFound,
                        Title =
                            "Resource not found",
                        Detail =
                            "The requested resource was not found."
                    },

                StatusCodes.Status405MethodNotAllowed =>
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status405MethodNotAllowed,
                        Title =
                            "Method not allowed",
                        Detail =
                            "The HTTP method is not allowed for this endpoint."
                    },

                _ =>
                    new ApiErrorResponse
                    {
                        StatusCode =
                            response.StatusCode,
                        Title =
                            "Request failed",
                        Detail =
                            "The request could not be completed."
                    }
            };

        response.ContentType =
            "application/problem+json";

        var json =
            JsonSerializer.Serialize(
                error,
                new JsonSerializerOptions
                {
                    PropertyNamingPolicy =
                        JsonNamingPolicy.CamelCase
                });

        await response.WriteAsync(json);
    });

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();

    app.UseSwaggerUI();
}

app.UseCors(
    CorsPolicyConstants
        .MindBloomClients);

app.UseRateLimiter();

app.UseAuthentication();

app.UseMiddleware<
    SecurityAuditMiddleware>();

app.UseAuthorization();

app.MapControllers();

app.MapHealthChecks(
        "/health/live",
        new HealthCheckOptions
        {
            Predicate =
                _ => false
        })
    .AllowAnonymous();

app.MapHealthChecks(
        "/health/ready",
        new HealthCheckOptions
        {
            Predicate =
                registration =>
                    registration.Tags
                        .Contains(
                            "ready")
        })
    .AllowAnonymous();

app.MapHub<NotificationHub>(
        "/hubs/notifications")
    .RequireAuthorization();

app.MapHub<ChatHub>(
        "/hubs/chat")
    .RequireAuthorization();

if (app.Environment.IsDevelopment())
{
    await DevelopmentDatabaseMigrator.MigrateAsync(
        app.Services);
}

var seedEnabled =
    app.Configuration
        .GetValue<bool>(
            "Seed:Enabled");

if (app.Environment.IsDevelopment() &&
    seedEnabled)
{
    using var scope =
        app.Services.CreateScope();

    var services =
        scope.ServiceProvider;

    var context =
        services.GetRequiredService<
            ApplicationDbContext>();

    var userManager =
        services.GetRequiredService<
            UserManager<ApplicationUser>>();

    var roleManager =
        services.GetRequiredService<
            RoleManager<IdentityRole<int>>>();

    await ApplicationDbSeeder.SeedAsync(
        context,
        userManager,
        roleManager);
}

app.Run();

static string ToCamelCase(
    string propertyName)
{
    if (string.IsNullOrWhiteSpace(
            propertyName))
    {
        return "request";
    }

    var normalized =
        propertyName.Trim();

    if (normalized.StartsWith(
            "$.",
            StringComparison.Ordinal))
    {
        normalized =
            normalized[2..];
    }

    if (normalized.Length == 1)
    {
        return normalized
            .ToLowerInvariant();
    }

    return
        char.ToLowerInvariant(
            normalized[0])
        + normalized[1..];
}

static void AddIpPolicy(
    RateLimiterOptions options,
    string policyName,
    RateLimitRuleOptions rule)
{
    options.AddPolicy(
        policyName,
        httpContext =>
            RateLimitPartition
                .GetFixedWindowLimiter(
                    partitionKey:
                        httpContext.Connection
                            .RemoteIpAddress?
                            .ToString()
                        ?? "unknown",

                    factory:
                        _ =>
                            CreateFixedWindowOptions(
                                rule)));
}

static void AddUserPolicy(
    RateLimiterOptions options,
    string policyName,
    RateLimitRuleOptions rule)
{
    options.AddPolicy(
        policyName,
        httpContext =>
        {
            var userId =
                httpContext.User
                    .FindFirst(
                        ClaimTypes
                            .NameIdentifier)?
                    .Value;

            var partitionKey =
                !string.IsNullOrWhiteSpace(
                    userId)
                    ? $"user:{userId}"
                    : $"ip:{httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown"}";

            return RateLimitPartition
                .GetFixedWindowLimiter(
                    partitionKey:
                        partitionKey,

                    factory:
                        _ =>
                            CreateFixedWindowOptions(
                                rule));
        });
}

static FixedWindowRateLimiterOptions
    CreateFixedWindowOptions(
        RateLimitRuleOptions rule)
{
    if (rule.PermitLimit <= 0)
    {
        throw new InvalidOperationException(
            "Rate limit PermitLimit must be greater than zero.");
    }

    if (rule.WindowSeconds <= 0)
    {
        throw new InvalidOperationException(
            "Rate limit WindowSeconds must be greater than zero.");
    }

    return new FixedWindowRateLimiterOptions
    {
        PermitLimit =
            rule.PermitLimit,

        Window =
            TimeSpan.FromSeconds(
                rule.WindowSeconds),

        QueueLimit =
            Math.Max(
                0,
                rule.QueueLimit),

        AutoReplenishment =
            true
    };
}

public partial class Program
{
}