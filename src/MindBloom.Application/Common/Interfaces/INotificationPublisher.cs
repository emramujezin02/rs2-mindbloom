using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.Application.Common.Interfaces;

public interface INotificationPublisher
{
    Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken = default);
}