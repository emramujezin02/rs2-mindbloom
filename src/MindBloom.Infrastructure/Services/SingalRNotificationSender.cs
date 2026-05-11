using MindBloom.Infrastructure.Realtime;
using MindBloom.Application.Common.Interfaces;
using Microsoft.AspNetCore.SignalR;

namespace MindBloom.Infrastructure.Services;

public class SignalRNotificationSender
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
        await _hubContext
            .Clients
            .Group($"user-{userId}")
            .SendAsync(
                "ReceiveNotification",
                new
                {
                    title,
                    message
                });
    }
}