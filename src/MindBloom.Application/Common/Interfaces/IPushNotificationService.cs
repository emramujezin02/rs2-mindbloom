namespace MindBloom.Application.Common.Interfaces;

public interface IPushNotificationService
{
    Task SendToUserAsync(
        int userId,
        string title,
        string message,
        IReadOnlyDictionary<string, string>?
            data = null,
        CancellationToken cancellationToken =
            default);
}