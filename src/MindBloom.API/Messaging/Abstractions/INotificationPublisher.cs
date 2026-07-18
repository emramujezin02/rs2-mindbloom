using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.API.Messaging.Abstractions;

public interface INotificationPublisher
{
    Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken = default);
}