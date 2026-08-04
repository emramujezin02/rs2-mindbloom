using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.API.Messaging.RabbitMq;

public sealed class RabbitMqNotificationPublisher
    : INotificationPublisher
{
    private readonly IIntegrationEventPublisher
        _integrationEventPublisher;

    private readonly RabbitMqOptions
        _options;

    public RabbitMqNotificationPublisher(
        IIntegrationEventPublisher
            integrationEventPublisher,
        Microsoft.Extensions.Options
            .IOptions<RabbitMqOptions>
            options)
    {
        _integrationEventPublisher =
            integrationEventPublisher;

        _options =
            options.Value;
    }

    public Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken =
            default)
    {
        ArgumentNullException.ThrowIfNull(
            message);

        ValidateMessage(
            message);

        return _integrationEventPublisher
            .PublishAsync(
                message,
                _options.EmailRoutingKey,
                cancellationToken);
    }

    private static void ValidateMessage(
        EmailNotificationMessage message)
    {
        if (message.EventType ==
            NotificationEventType.Unknown)
        {
            throw new ArgumentException(
                "RabbitMQ notification EventType cannot be Unknown.",
                nameof(message));
        }

        if (string.IsNullOrWhiteSpace(
                message.RecipientEmail))
        {
            throw new ArgumentException(
                "Email notification recipient is required.",
                nameof(message));
        }

        if (string.IsNullOrWhiteSpace(
                message.Subject))
        {
            throw new ArgumentException(
                "Email notification subject is required.",
                nameof(message));
        }

        var hasBody =
            !string.IsNullOrWhiteSpace(
                message.Body);

        var hasTemplate =
            !string.IsNullOrWhiteSpace(
                message.TemplateName);

        if (!hasBody &&
            !hasTemplate)
        {
            throw new ArgumentException(
                "Email notification must contain either Body or TemplateName.",
                nameof(message));
        }

        if (message.RetryCount < 0)
        {
            throw new ArgumentException(
                "RetryCount cannot be negative.",
                nameof(message));
        }
    }
}