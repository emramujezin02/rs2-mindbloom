using MindBloom.Application.Common.Interfaces;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.API.Messaging.Mock;

public sealed class MockNotificationPublisher
    : INotificationPublisher
{
    private static readonly EventId
        MockEmailQueuedEvent =
            new(
                3200,
                "MockEmailQueued");

    private readonly ILogger<MockNotificationPublisher>
        _logger;

    public MockNotificationPublisher(
        ILogger<MockNotificationPublisher> logger)
    {
        _logger =
            logger;
    }

    public Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken =
            default)
    {
        ArgumentNullException.ThrowIfNull(
            message);

        cancellationToken.ThrowIfCancellationRequested();

        _logger.LogInformation(
            MockEmailQueuedEvent,
            "Mock email notification accepted. "
            + "Module: {Module}, "
            + "EventType: {EventType}, "
            + "RecipientPresent: {RecipientPresent}.",
            "Notifications",
            message.EventType,
            !string.IsNullOrWhiteSpace(
                message.RecipientEmail));

        return Task.CompletedTask;
    }
}
