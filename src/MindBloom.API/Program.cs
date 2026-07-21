using DotNetEnv;
using FluentValidation;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi.Models;
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

Env.Load("../../.env");

Env.TraversePath().Load();

var builder =
    WebApplication.CreateBuilder(args);

builder.Configuration
    .AddEnvironmentVariables();

builder.Services
    .AddValidatorsFromAssemblyContaining<
        RegisterRequestDtoValidator>();

builder.Services
    .AddScoped<FluentValidationFilter>();

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
                            StringComparer
                                .OrdinalIgnoreCase);

                return new BadRequestObjectResult(
                    new ValidationErrorResponse
                    {
                        Errors = errors
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

var app =
    builder.Build();

app.UseMiddleware<
    GlobalExceptionMiddleware>();

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
    "/hubs/chat");

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