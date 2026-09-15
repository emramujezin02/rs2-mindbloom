using Microsoft.AspNetCore.SignalR;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Realtime;

namespace MindBloom.Infrastructure.Services;

public sealed class SignalRNotificationSender
    : INotificationSender
{
    private readonly IHubContext<NotificationHub>
        _hubContext;

    public SignalRNotificationSender(
        IHubContext<NotificationHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public async Task SendToUserAsync(
        int userId,
        string title,
        string message)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "User identifier is invalid.",
                nameof(userId));
        }

        await _hubContext
            .Clients
            .Group(GetUserGroupName(userId))
            .SendAsync(
                "ReceiveNotification",
                new
                {
                    title,
                    message,
                    createdAtUtc =
                        DateTime.UtcNow
                });
    }

    private static string GetUserGroupName(
        int userId)
    {
        return $"user-{userId}";
    }
}