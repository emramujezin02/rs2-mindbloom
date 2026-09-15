using MindBloom.Application.Common.Interfaces;

namespace MindBloom.NotificationsWorker.Services;

public sealed class NoOpPushNotificationService
    : IPushNotificationService
{
    public Task SendToUserAsync(
        int userId,
        string title,
        string message,
        IReadOnlyDictionary<
            string,
            string>? data = null,
        CancellationToken cancellationToken =
            default)
    {
        cancellationToken
            .ThrowIfCancellationRequested();

        return Task.CompletedTask;
    }
}