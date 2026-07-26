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


Env.Load("../../.env");

Env.TraversePath().Load();

var builder =
    WebApplication.CreateBuilder(args);

builder.Configuration
    .AddEnvironmentVariables();

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

builder.Services.AddHealthChecks();

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

builder.Services.AddCors(options =>
{
    options.AddPolicy(
        "AllowAll",
        policy =>
        {
            policy
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowAnyOrigin();
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

var app = builder.Build();

app.UseStaticFiles();

app.UseMiddleware<
    CorrelationIdMiddleware>();

app.UseMiddleware<
    RequestTimingMiddleware>();

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

app.UseSwagger();

app.UseSwaggerUI();

app.UseCors("AllowAll");

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.MapHealthChecks("/health");

app.MapHub<NotificationHub>(
        "/hubs/notifications")
    .RequireAuthorization();

app.MapHub<ChatHub>(
        "/hubs/chat")
    .RequireAuthorization();

using (var scope =
       app.Services.CreateScope())
{
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
            RoleManager<
                IdentityRole<int>>>();

    await ApplicationDbSeeder
        .SeedAsync(
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