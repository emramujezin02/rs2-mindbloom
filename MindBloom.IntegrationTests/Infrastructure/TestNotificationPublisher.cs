using System.Collections.Concurrent;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.IntegrationTests.Infrastructure;

public sealed class TestNotificationPublisher
    : INotificationPublisher
{
    private readonly ConcurrentQueue<
        EmailNotificationMessage>
        _messages = new();

    public IReadOnlyList<
        EmailNotificationMessage>
        Messages =>
            _messages.ToArray();

    public Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken =
            default)
    {
        cancellationToken
            .ThrowIfCancellationRequested();

        ArgumentNullException.ThrowIfNull(
            message);

        _messages.Enqueue(
            message);

        return Task.CompletedTask;
    }

    public void Reset()
    {
        while (_messages.TryDequeue(
                   out _))
        {
        }
    }
}