using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Realtime;

namespace MindBloom.Infrastructure.Services;

public class NotificationService : INotificationService
{
    private readonly ApplicationDbContext _context;
    private readonly IHubContext<NotificationHub> _hubContext;
    public NotificationService(
        ApplicationDbContext context, IHubContext<NotificationHub> hubContext)
    {
        _context = context;
        _hubContext = hubContext;
    }

    public async Task<List<NotificationResponseDto>>
        GetMyNotificationsAsync(int userId)
    {
        return await _context.Notifications
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new NotificationResponseDto
            {
                Id = x.Id,
                Title = x.Title,
                Message = x.Message,
                IsRead = x.IsRead,
                CreatedAtUtc = x.CreatedAtUtc
            })
            .ToListAsync();
    }

    public async Task MarkAsReadAsync(
        int userId,
        int notificationId)
    {
        var notification =
            await _context.Notifications
                .FirstOrDefaultAsync(x =>
                    x.Id == notificationId
                    && x.UserId == userId);

        if (notification == null)
        {
            throw new Exception(
                "Notification not found.");
        }

        notification.IsRead = true;

        await _context.SaveChangesAsync();
    }

    public async Task SendRealtimeNotificationAsync(
    int userId,
    string title,
    string message)
    {
        await _hubContext.Clients
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