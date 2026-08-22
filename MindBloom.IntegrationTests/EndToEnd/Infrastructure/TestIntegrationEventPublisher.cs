using System.Collections.Concurrent;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.IntegrationTests.EndToEnd.Infrastructure;

public sealed class TestIntegrationEventPublisher
    : IIntegrationEventPublisher
{
    private readonly ConcurrentQueue<
        PublishedIntegrationEvent>
        _events =
            new();

    public IReadOnlyList<
        PublishedIntegrationEvent>
        Events =>
            _events.ToArray();

    public Task PublishAsync(
        IntegrationEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken =
            default)
    {
        cancellationToken
            .ThrowIfCancellationRequested();

        ArgumentNullException.ThrowIfNull(
            integrationEvent);

        _events.Enqueue(
            new PublishedIntegrationEvent(
                integrationEvent,
                routingKey));

        return Task.CompletedTask;
    }

    public Task PublishAsync<TEvent>(
        TEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken =
            default)
        where TEvent : IntegrationEvent
    {
        cancellationToken
            .ThrowIfCancellationRequested();

        ArgumentNullException.ThrowIfNull(
            integrationEvent);

        _events.Enqueue(
            new PublishedIntegrationEvent(
                integrationEvent,
                routingKey));

        return Task.CompletedTask;
    }

    public void Reset()
    {
        while (_events.TryDequeue(
                   out _))
        {
        }
    }

    public sealed record
        PublishedIntegrationEvent(
            IntegrationEvent Event,
            string RoutingKey);
}