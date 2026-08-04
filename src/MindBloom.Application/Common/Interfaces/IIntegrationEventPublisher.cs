using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Application.Common.Interfaces;

public interface IIntegrationEventPublisher
{
    Task PublishAsync<TEvent>(
        TEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken = default)
        where TEvent : IntegrationEvent;
}