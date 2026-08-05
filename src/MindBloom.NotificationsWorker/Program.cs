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

Env.TraversePath().Load();

var builder =
    Host.CreateApplicationBuilder(args);

builder.Configuration
    .AddEnvironmentVariables();

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

builder.Services.AddHostedService<
    DeadLetterQueueMonitor>();

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

var host =
    builder.Build();

await host.RunAsync();