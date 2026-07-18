using MindBloom.API.Messaging.Abstractions;
using MindBloom.API.Messaging.Configuration;
using MindBloom.API.Messaging.RabbitMq;
using MindBloom.Application.Common.Exceptions;

namespace MindBloom.API.Messaging.DependencyInjection;

public static class MessagingDependencyInjection
{
    public static IServiceCollection AddNotificationMessaging(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<RabbitMqOptions>()
            .Configure(options =>
            {
                options.HostName = GetRequiredValue(
                    configuration,
                    "RABBITMQ_HOST");

                options.Port = GetIntValue(
                    configuration,
                    "RABBITMQ_PORT",
                    5672);

                options.UserName = GetRequiredValue(
                    configuration,
                    "RABBITMQ_USERNAME");

                options.Password = GetRequiredValue(
                    configuration,
                    "RABBITMQ_PASSWORD");

                options.VirtualHost =
                    configuration["RABBITMQ_VIRTUAL_HOST"]
                    ?? "/";

                options.ClientProvidedName =
                    configuration["RABBITMQ_CLIENT_NAME"]
                    ?? "mindbloom-api-notification-publisher";

                options.NotificationExchange =
                    configuration["RABBITMQ_NOTIFICATION_EXCHANGE"]
                    ?? "mindbloom.notifications";

                options.EmailQueue =
                    configuration["RABBITMQ_EMAIL_QUEUE"]
                    ?? "mindbloom.notifications.email";

                options.EmailRoutingKey =
                    configuration["RABBITMQ_EMAIL_ROUTING_KEY"]
                    ?? "notification.email";

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
            .ValidateOnStart();

        services.AddSingleton<RabbitMqConnectionManager>();

        services.AddSingleton<
            INotificationPublisher,
            RabbitMqNotificationPublisher>();

        return services;
    }

    private static string GetRequiredValue(
        IConfiguration configuration,
        string key)
    {
        var value = configuration[key];

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new BadRequestException(
                $"Environment variable '{key}' is required.");
        }

        return value;
    }

    private static int GetIntValue(
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

    private static bool GetBoolValue(
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
}