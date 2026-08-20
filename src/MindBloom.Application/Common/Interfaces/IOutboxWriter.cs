using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Application.Common.Interfaces;

public interface IOutboxWriter
{
    Task EnqueueAsync<TEvent>(
        TEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken =
            default,
        string? idempotencyKey =
            null)
        where TEvent : IntegrationEvent;
}