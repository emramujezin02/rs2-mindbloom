using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MindBloom.Infrastructure.Messaging.RabbitMq;

public static class RabbitMqConfigurationExtensions
{
    public static IServiceCollection
        AddStandardRabbitMqConfiguration(
            this IServiceCollection services,
            IConfiguration configuration)
    {
        services
            .AddOptions<RabbitMqOptions>()
            .Configure(options =>
            {
                options.HostName =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_HOST");

                options.Port =
                    GetIntValue(
                        configuration,
                        "RABBITMQ_PORT",
                        5672);

                options.UserName =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_USERNAME");

                options.Password =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_PASSWORD");

                options.VirtualHost =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_VIRTUAL_HOST");

                options.PublisherClientName =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_CLIENT_NAME");

                options.ConsumerClientName =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_WORKER_CLIENT_NAME");

                options.NotificationExchange =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_NOTIFICATION_EXCHANGE");

                options.EmailQueue =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_EMAIL_QUEUE");

                options.EmailRoutingKey =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_EMAIL_ROUTING_KEY");

                options.RetryExchange =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_RETRY_EXCHANGE");

                options.DeadLetterExchange =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_DEAD_LETTER_EXCHANGE");

                options.DeadLetterQueue =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_EMAIL_DEAD_LETTER_QUEUE");

                options.DeadLetterRoutingKey =
                    GetRequiredValue(
                        configuration,
                        "RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY");

                options.PrefetchCount =
                    GetUShortValue(
                        configuration,
                        "RABBITMQ_PREFETCH_COUNT",
                        1);

                options.MaximumRetryCount =
                    GetIntValue(
                        configuration,
                        "RABBITMQ_MAXIMUM_RETRY_COUNT",
                        4);

                options.AutomaticRecoveryEnabled =
                    GetBoolValue(
                        configuration,
                        "RABBITMQ_AUTOMATIC_RECOVERY",
                        true);

                options.NetworkRecoveryIntervalSeconds =
                    GetIntValue(
                        configuration,
                        "RABBITMQ_RECOVERY_INTERVAL_SECONDS",
                        5);

                options.RequestedHeartbeatSeconds =
                    GetIntValue(
                        configuration,
                        "RABBITMQ_HEARTBEAT_SECONDS",
                        30);

                options.ConnectionRetryCount =
                    GetIntValue(
                        configuration,
                        "RABBITMQ_CONNECTION_RETRY_COUNT",
                        5);

                options.IntegrationEventQueue =
    configuration[
        "RABBITMQ_INTEGRATION_EVENT_QUEUE"]
    ?? "mindbloom.integration-events";

                options.IntegrationEventDeadLetterQueue =
                    configuration[
                        "RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_QUEUE"]
                    ?? "mindbloom.integration-events.dlq";

                options.IntegrationEventDeadLetterRoutingKey =
                    configuration[
                        "RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_ROUTING_KEY"]
                    ?? "integration-event.dead";

                options.ConnectionRetryDelaySeconds =
                    GetIntValue(
                        configuration,
                        "RABBITMQ_CONNECTION_RETRY_DELAY_SECONDS",
                        3);
            })
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.HostName),
                "RABBITMQ_HOST is required.")
            .Validate(
                options =>
                    options.Port is > 0 and <= 65535,
                "RABBITMQ_PORT must be between 1 and 65535.")
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
                    !string.IsNullOrWhiteSpace(
                        options.VirtualHost),
                "RABBITMQ_VIRTUAL_HOST is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.PublisherClientName),
                "RABBITMQ_CLIENT_NAME is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.ConsumerClientName),
                "RABBITMQ_WORKER_CLIENT_NAME is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.NotificationExchange),
                "RABBITMQ_NOTIFICATION_EXCHANGE is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.EmailQueue),
                "RABBITMQ_EMAIL_QUEUE is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.EmailRoutingKey),
                "RABBITMQ_EMAIL_ROUTING_KEY is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.RetryExchange),
                "RABBITMQ_RETRY_EXCHANGE is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.DeadLetterExchange),
                "RABBITMQ_DEAD_LETTER_EXCHANGE is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.DeadLetterQueue),
                "RABBITMQ_EMAIL_DEAD_LETTER_QUEUE is required.")
            .Validate(
                options =>
                    !string.IsNullOrWhiteSpace(
                        options.DeadLetterRoutingKey),
                "RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY is required.")
            .Validate(
                options =>
                    options.PrefetchCount > 0,
                "RABBITMQ_PREFETCH_COUNT must be greater than zero.")
            .Validate(
                options =>
                    options.MaximumRetryCount == 4,
                "RABBITMQ_MAXIMUM_RETRY_COUNT must be 4 because the configured retry delays are 1s, 2s, 4s and 8s.")
            .Validate(
                options =>
                    options.NetworkRecoveryIntervalSeconds > 0,
                "RABBITMQ_RECOVERY_INTERVAL_SECONDS must be greater than zero.")
            .Validate(
                options =>
                    options.RequestedHeartbeatSeconds > 0,
                "RABBITMQ_HEARTBEAT_SECONDS must be greater than zero.")
            .Validate(
                options =>
                    options.ConnectionRetryCount > 0,
                "RABBITMQ_CONNECTION_RETRY_COUNT must be greater than zero.")
            .Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options.IntegrationEventQueue),
    "RabbitMQ integration event queue is required.")
.Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options
                .IntegrationEventDeadLetterQueue),
    "RabbitMQ integration event dead-letter queue is required.")
.Validate(
    options =>
        !string.IsNullOrWhiteSpace(
            options
                .IntegrationEventDeadLetterRoutingKey),
    "RabbitMQ integration event dead-letter routing key is required.")
            .Validate(
                options =>
                    options.ConnectionRetryDelaySeconds > 0,
                "RABBITMQ_CONNECTION_RETRY_DELAY_SECONDS must be greater than zero.")
            .ValidateOnStart();

        services.AddSingleton<RabbitMqConnectionFactory>();

        services.AddSingleton<RabbitMqTopology>();

        return services;
    }

    private static string GetRequiredValue(
        IConfiguration configuration,
        string key)
    {
        var value =
            configuration[key];

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"RabbitMQ configuration value '{key}' is required.");
        }

        return value.Trim();
    }

    private static int GetIntValue(
        IConfiguration configuration,
        string key,
        int defaultValue)
    {
        var value =
            configuration[key];

        if (string.IsNullOrWhiteSpace(value))
        {
            return defaultValue;
        }

        if (!int.TryParse(
                value,
                out var parsedValue))
        {
            throw new InvalidOperationException(
                $"RabbitMQ configuration value '{key}' must be a valid integer.");
        }

        return parsedValue;
    }

    private static ushort GetUShortValue(
        IConfiguration configuration,
        string key,
        ushort defaultValue)
    {
        var value =
            configuration[key];

        if (string.IsNullOrWhiteSpace(value))
        {
            return defaultValue;
        }

        if (!ushort.TryParse(
                value,
                out var parsedValue))
        {
            throw new InvalidOperationException(
                $"RabbitMQ configuration value '{key}' must be a valid positive number.");
        }

        return parsedValue;
    }

    private static bool GetBoolValue(
        IConfiguration configuration,
        string key,
        bool defaultValue)
    {
        var value =
            configuration[key];

        if (string.IsNullOrWhiteSpace(value))
        {
            return defaultValue;
        }

        if (!bool.TryParse(
                value,
                out var parsedValue))
        {
            throw new InvalidOperationException(
                $"RabbitMQ configuration value '{key}' must be true or false.");
        }

        return parsedValue;
    }
}