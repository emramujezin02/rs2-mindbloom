using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class NotificationService : INotificationService
{
    private readonly ApplicationDbContext _context;

    public NotificationService(
        ApplicationDbContext context)
    {
        _context = context;
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
}