using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.NotificationsWorker.Dispatching;

public interface IIntegrationEventDispatcher
{
    Task DispatchAsync(
        IntegrationEvent integrationEvent,
        CancellationToken cancellationToken);
}