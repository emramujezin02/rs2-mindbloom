using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.NotificationsWorker.Handlers;

public interface IIntegrationEventHandler<in TEvent>
    where TEvent : IntegrationEvent
{
    Task HandleAsync(
        TEvent integrationEvent,
        CancellationToken cancellationToken);
}