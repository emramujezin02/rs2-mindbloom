using DotNetEnv;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Services;
using MindBloom.NotificationsWorker.Configuration;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Workers;

Env.TraversePath().Load();

var builder = Host.CreateApplicationBuilder(args);

builder.Configuration.AddEnvironmentVariables();

builder.Services
    .AddOptions<RabbitMqConsumerOptions>()
    .Configure(options =>
    {
        options.HostName = GetRequiredValue(
            builder.Configuration,
            "RABBITMQ_HOST");

        options.Port = GetIntValue(
            builder.Configuration,
            "RABBITMQ_PORT",
            5672);

        options.UserName = GetRequiredValue(
            builder.Configuration,
            "RABBITMQ_USERNAME");

        options.Password = GetRequiredValue(
            builder.Configuration,
            "RABBITMQ_PASSWORD");

        options.VirtualHost =
            builder.Configuration["RABBITMQ_VIRTUAL_HOST"]
            ?? "/";

        options.ClientProvidedName =
            builder.Configuration["RABBITMQ_WORKER_CLIENT_NAME"]
            ?? "mindbloom-notifications-worker";

        options.NotificationExchange =
            builder.Configuration[
                "RABBITMQ_NOTIFICATION_EXCHANGE"]
            ?? "mindbloom.notifications";

        options.EmailQueue =
            builder.Configuration["RABBITMQ_EMAIL_QUEUE"]
            ?? "mindbloom.notifications.email";

        options.EmailRoutingKey =
            builder.Configuration[
                "RABBITMQ_EMAIL_ROUTING_KEY"]
            ?? "notification.email";

        options.RetryExchange =
    builder.Configuration[
        "RABBITMQ_RETRY_EXCHANGE"]
    ?? "mindbloom.notifications.retry";

        options.DeadLetterExchange =
            builder.Configuration[
                "RABBITMQ_DEAD_LETTER_EXCHANGE"]
            ?? "mindbloom.notifications.dead-letter";

        options.DeadLetterQueue =
            builder.Configuration[
                "RABBITMQ_EMAIL_DEAD_LETTER_QUEUE"]
            ?? "mindbloom.notifications.email.dlq";

        options.DeadLetterRoutingKey =
            builder.Configuration[
                "RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY"]
            ?? "notification.email.dead";

        options.MaximumRetryCount =
            GetIntValue(
                builder.Configuration,
                "RABBITMQ_MAXIMUM_RETRY_COUNT",
                4);

        options.PrefetchCount = GetUShortValue(
            builder.Configuration,
            "RABBITMQ_PREFETCH_COUNT",
            1);

        options.AutomaticRecoveryEnabled =
            GetBoolValue(
                builder.Configuration,
                "RABBITMQ_AUTOMATIC_RECOVERY",
                true);

        options.NetworkRecoveryIntervalSeconds =
            GetIntValue(
                builder.Configuration,
                "RABBITMQ_RECOVERY_INTERVAL_SECONDS",
                5);

        options.RequestedHeartbeatSeconds =
            GetIntValue(
                builder.Configuration,
                "RABBITMQ_HEARTBEAT_SECONDS",
                30);
    })
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.HostName),
        "RABBITMQ_HOST is required.")
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.UserName),
        "RABBITMQ_USERNAME is required.")
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.Password),
        "RABBITMQ_PASSWORD is required.")
    .Validate(
        options =>
            options.Port is > 0 and <= 65535,
        "RABBITMQ_PORT must be between 1 and 65535.")
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.NotificationExchange),
        "RabbitMQ notification exchange is required.")
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.EmailQueue),
        "RabbitMQ email queue is required.")
    .Validate(
        options =>
            !string.IsNullOrWhiteSpace(
                options.EmailRoutingKey),
        "RabbitMQ email routing key is required.")
    .Validate(
        options => options.PrefetchCount > 0,
        "RabbitMQ prefetch count must be greater than zero.")
    .Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options.RetryExchange),
    "RabbitMQ retry exchange is required.")
.Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options.DeadLetterExchange),
    "RabbitMQ dead-letter exchange is required.")
.Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options.DeadLetterQueue),
    "RabbitMQ dead-letter queue is required.")
.Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options.DeadLetterRoutingKey),
    "RabbitMQ dead-letter routing key is required.")
.Validate(
    options =>
        options.MaximumRetryCount == 4,
    "RabbitMQ maximum retry count must be 4 because the configured delays are 1s, 2s, 4s and 8s.")
    .ValidateOnStart();

builder.Services.AddSingleton<IEmailService, EmailService>();

builder.Services.AddSingleton<EmailMessageBodyBuilder>();

builder.Services.AddHostedService<EmailNotificationConsumer>();

var host = builder.Build();

await host.RunAsync();

static string GetRequiredValue(
    IConfiguration configuration,
    string key)
{
    var value = configuration[key];

    if (string.IsNullOrWhiteSpace(value))
    {
        throw new InvalidOperationException(
            $"Environment variable '{key}' is required.");
    }

    return value;
}

static int GetIntValue(
    IConfiguration configuration,
    string key,
    int defaultValue)
{
    var value = configuration[key];

    if (string.IsNullOrWhiteSpace(value))
    {
        return defaultValue;
    }

    if (!int.TryParse(value, out var parsedValue))
    {
        throw new InvalidOperationException(
            $"Environment variable '{key}' must be a valid integer.");
    }

    return parsedValue;
}

static ushort GetUShortValue(
    IConfiguration configuration,
    string key,
    ushort defaultValue)
{
    var value = configuration[key];

    if (string.IsNullOrWhiteSpace(value))
    {
        return defaultValue;
    }

    if (!ushort.TryParse(value, out var parsedValue))
    {
        throw new InvalidOperationException(
            $"Environment variable '{key}' must be a valid positive number.");
    }

    return parsedValue;
}

static bool GetBoolValue(
    IConfiguration configuration,
    string key,
    bool defaultValue)
{
    var value = configuration[key];

    if (string.IsNullOrWhiteSpace(value))
    {
        return defaultValue;
    }

    if (!bool.TryParse(value, out var parsedValue))
    {
        throw new InvalidOperationException(
            $"Environment variable '{key}' must be true or false.");
    }

    return parsedValue;
}