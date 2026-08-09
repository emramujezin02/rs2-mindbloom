using DotNetEnv;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Infrastructure.Services;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Workers;
using Microsoft.EntityFrameworkCore;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Handlers;
using MindBloom.NotificationsWorker.Handlers.Appointments;
using MindBloom.Messaging.Contracts.Chat;
using MindBloom.Messaging.Contracts.Memberships;
using MindBloom.NotificationsWorker.Handlers.Chat;
using MindBloom.NotificationsWorker.Handlers.Memberships;
using MindBloom.Messaging.Contracts.Articles;
using MindBloom.Messaging.Contracts.Reviews;
using MindBloom.Messaging.Contracts.Workshops;
using MindBloom.NotificationsWorker.Handlers.Articles;
using MindBloom.NotificationsWorker.Handlers.Reviews;
using MindBloom.NotificationsWorker.Handlers.Workshops;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.NotificationsWorker.Handlers.Notifications;
using MindBloom.NotificationsWorker.Handlers.Payments;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;
using MindBloom.NotificationsWorker.Configuration;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using MindBloom.NotificationsWorker.Health;
using MindBloom.NotificationsWorker.Monitoring;
using MindBloom.NotificationsWorker.Messaging;

Env.TraversePath().Load();

var builder =
    WebApplication.CreateBuilder(args);

builder.Configuration
    .AddEnvironmentVariables();

WorkerEnvironmentConfigurationValidator
    .Validate(
        builder.Configuration);

builder.Services
    .AddHealthChecks()

    .AddDbContextCheck<
        ApplicationDbContext>(
        name:
            "database",
        failureStatus:
            HealthStatus.Unhealthy,
        tags:
            new[]
            {
                "worker",
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
                "worker",
                "ready",
                "rabbitmq"
            })

    .AddCheck<EmailProviderHealthCheck>(
        name:
            "email-provider",
        failureStatus:
            HealthStatus.Unhealthy,
        tags:
            new[]
            {
                "worker",
                "ready",
                "email"
            })

    .AddCheck<FirebaseHealthCheck>(
        name:
            "firebase",
        failureStatus:
            HealthStatus.Unhealthy,
        tags:
            new[]
            {
                "worker",
                "ready",
                "firebase"
            });

builder.Services
    .AddOptions<FirebasePushOptions>()
    .Configure(options =>
    {
        options.CredentialsPath =
            builder.Configuration[
                "FIREBASE_CREDENTIALS_PATH"]
            ?? string.Empty;

        options.BatchSize =
            GetIntValue(
                builder.Configuration,
                "FIREBASE_BATCH_SIZE",
                500);

        options.RetryCount =
            GetIntValue(
                builder.Configuration,
                "FIREBASE_RETRY_COUNT",
                3);

        options.RetryDelaySeconds =
            GetIntValue(
                builder.Configuration,
                "FIREBASE_RETRY_DELAY_SECONDS",
                2);
    })
    .Validate(
        options =>
            options.BatchSize is > 0 and <= 500,
        "Firebase batch size must be between 1 and 500.")
    .Validate(
        options =>
            options.RetryCount >= 0,
        "Firebase retry count cannot be negative.")
    .Validate(
        options =>
            options.RetryDelaySeconds > 0,
        "Firebase retry delay must be greater than zero.")
    .ValidateOnStart();

var connectionString =
    builder.Configuration["DB_CONNECTION"];

if (string.IsNullOrWhiteSpace(
        connectionString))
{
    throw new InvalidOperationException(
        "Environment variable 'DB_CONNECTION' is required.");
}

builder.Services.AddDbContext<
    ApplicationDbContext>(
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

builder.Services
    .AddStandardRabbitMqConfiguration(
        builder.Configuration);

builder.Services.AddSingleton<
    IEmailService,
    EmailService>();

builder.Services.AddSingleton<
    RabbitMqConsumerOperations>();

builder.Services.AddSingleton<
    RabbitMqWorkerConnectionProvider>();

builder.Services.AddSingleton<
    EmailMessageBodyBuilder>();

builder.Services.AddScoped<
    WorkerNotificationService>();

builder.Services.AddSingleton<
    IntegrationEventDeserializer>();

builder.Services.AddSingleton<
    IIntegrationEventDispatcher,
    IntegrationEventDispatcher>();

builder.Services.AddHostedService<
    EmailNotificationConsumer>();

builder.Services.AddHostedService<
    IntegrationEventConsumer>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        AppointmentCreatedEvent>,
    AppointmentCreatedEventHandler>();

builder.Services.AddScoped<
    ProcessedMessageService>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        AppointmentAcceptedEvent>,
    AppointmentAcceptedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        AppointmentRejectedEvent>,
    AppointmentRejectedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        AppointmentCancelledEvent>,
    AppointmentCancelledEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        AppointmentCompletedEvent>,
    AppointmentCompletedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        ChatMessageCreatedEvent>,
    ChatMessageCreatedEventHandler>();

builder.Services.AddScoped<
    IPushNotificationService,
    FirebasePushNotificationService>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        MembershipPurchasedEvent>,
    MembershipPurchasedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        MembershipExpiredEvent>,
    MembershipExpiredEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        WorkshopCreatedEvent>,
    WorkshopCreatedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        WorkshopUpdatedEvent>,
    WorkshopUpdatedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        WorkshopCancelledEvent>,
    WorkshopCancelledEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        ArticlePublishedEvent>,
    ArticlePublishedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        ReviewApprovedEvent>,
    ReviewApprovedEventHandler>();

builder.Services.AddHostedService<
    RabbitMqMonitoringService>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        PaymentSucceededEvent>,
    PaymentSucceededEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        PaymentRefundedEvent>,
    PaymentRefundedEventHandler>();

builder.Services.AddScoped<
    IIntegrationEventHandler<
        NotificationRequestedEvent>,
    NotificationRequestedEventHandler>();

builder.Services.AddSingleton<
    RabbitMqMonitoringMetrics>();

builder.Services.AddSingleton(
    serviceProvider =>
    {
        var options =
            serviceProvider
                .GetRequiredService<
                    IOptions<
                        FirebasePushOptions>>()
                .Value;

        if (string.IsNullOrWhiteSpace(
                options.CredentialsPath))
        {
            throw new InvalidOperationException(
                "FIREBASE_CREDENTIALS_PATH is not configured.");
        }

        if (!File.Exists(
                options.CredentialsPath))
        {
            throw new InvalidOperationException(
                $"Firebase credentials file was not found at '{options.CredentialsPath}'.");
        }

        var credential =
            GoogleCredential.FromFile(
                options.CredentialsPath);

        return FirebaseApp.Create(
            new AppOptions
            {
                Credential =
                    credential
            });
    });

builder.Services.AddSingleton(
    serviceProvider =>
    {
        var firebaseApp =
            serviceProvider
                .GetRequiredService<
                    FirebaseApp>();

        return FirebaseMessaging
            .GetMessaging(
                firebaseApp);
    });

var app =
    builder.Build();

var logger =
    app.Services
        .GetRequiredService<
            ILoggerFactory>()
        .CreateLogger(
            "MindBloom.NotificationsWorker");

var lifetime =
    app.Services
        .GetRequiredService<
            IHostApplicationLifetime>();

lifetime.ApplicationStarted.Register(
    () =>
    {
        logger.LogInformation(
            "MindBloom Notifications Worker started successfully.");
    });

lifetime.ApplicationStopping.Register(
    () =>
    {
        logger.LogInformation(
            "MindBloom Notifications Worker is stopping.");
    });

lifetime.ApplicationStopped.Register(
    () =>
    {
        logger.LogInformation(
            "MindBloom Notifications Worker stopped successfully.");
    });

app.MapHealthChecks(
    "/health/live",
    new HealthCheckOptions
    {
        Predicate =
            _ => false
    });

app.MapHealthChecks(
    "/health/ready",
    new HealthCheckOptions
    {
        Predicate =
            registration =>
                registration.Tags
                    .Contains(
                        "ready"),

        ResponseWriter =
            async (
                context,
                report) =>
            {
                context.Response.ContentType =
                    "application/json";

                var response =
                    new
                    {
                        status =
                            report.Status
                                .ToString(),

                        worker =
                            "MindBloom.NotificationsWorker",

                        checkedAtUtc =
                            DateTime.UtcNow,

                        checks =
                            report.Entries
                                .Select(
                                    entry =>
                                        new
                                        {
                                            name =
                                                entry.Key,

                                            status =
                                                entry.Value
                                                    .Status
                                                    .ToString(),

                                            description =
                                                entry.Value
                                                    .Description,

                                            duration =
                                                entry.Value
                                                    .Duration
                                                    .TotalMilliseconds
                                        })
                    };

                await context.Response
                    .WriteAsync(
                        JsonSerializer
                            .Serialize(
                                response));
            }
    });

await app.RunAsync();

static int GetIntValue(
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
            out var parsedValue))
    {
        throw new InvalidOperationException(
            $"Environment variable '{key}' must be a valid integer.");
    }

    return parsedValue;
}