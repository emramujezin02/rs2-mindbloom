using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class NotificationService
    : INotificationService
{
    private static readonly EventId
    NotificationMarkedAsReadEvent =
        new(
            3510,
            "NotificationMarkedAsRead");

    private static readonly EventId
        AllNotificationsMarkedAsReadEvent =
            new(
                3511,
                "AllNotificationsMarkedAsRead");

    private readonly ApplicationDbContext
        _context;

    private readonly ILogger<
        NotificationService>
        _logger;

    public NotificationService(
        ApplicationDbContext context,
        ILogger<NotificationService> logger)
    {
        _context =
            context;

        _logger =
            logger;
    }

    public async Task<NotificationPageResponseDto>
        GetMyNotificationsAsync(
            int userId,
            NotificationQueryDto request)
    {
        var pagination =
            PaginationHelper.Normalize(
                request.PageNumber,
                request.PageSize);

        var query =
            _context.Notifications
                .AsNoTracking()
                .Where(notification =>
                    notification.UserId == userId &&
                    !notification.IsDeleted);

        if (request.IsRead.HasValue)
        {
            query = query.Where(notification =>
                notification.IsRead ==
                request.IsRead.Value);
        }

        var totalCount =
            await query.CountAsync();

        var unreadCount =
            await _context.Notifications
                .AsNoTracking()
                .CountAsync(notification =>
                    notification.UserId == userId &&
                    !notification.IsDeleted &&
                    !notification.IsRead);

        var notifications =
            await query
                .OrderByDescending(notification =>
                    notification.CreatedAtUtc)
                .ThenByDescending(notification =>
                    notification.Id)
                .Skip(pagination.Skip)
                .Take(pagination.PageSize)
                .Select(notification =>
                    new NotificationResponseDto
                    {
                        Id =
                            notification.Id,

                        Title =
                            notification.Title,

                        Message =
                            notification.Message,

                        IsRead =
                            notification.IsRead,

                        CreatedAtUtc =
                            notification.CreatedAtUtc,

                        ActionType =
                            notification.ActionType
                                .ToString(),

                        AppointmentId =
                            notification.AppointmentId,

                        ResourceId =
                            notification.ResourceId,

                        IsActionAvailable =
                            true
                    })
                .ToListAsync();

        await ResolveActionAvailabilityAsync(
            userId,
            notifications);

        var totalPages =
            totalCount == 0
                ? 0
                : (int)Math.Ceiling(
                    totalCount /
                    (double)pagination.PageSize);

        return new NotificationPageResponseDto
        {
            Items =
                notifications,

            PageNumber =
                pagination.PageNumber,

            PageSize =
                pagination.PageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalPages,

            UnreadCount =
                unreadCount
        };
    }

    public Task<int> GetUnreadCountAsync(
        int userId)
    {
        return _context.Notifications
            .AsNoTracking()
            .CountAsync(notification =>
                notification.UserId == userId &&
                !notification.IsDeleted &&
                !notification.IsRead);
    }

    public async Task MarkAsReadAsync(
        int userId,
        int notificationId)
    {
        var notification =
            await _context.Notifications
                .FirstOrDefaultAsync(x =>
                    x.Id == notificationId &&
                    x.UserId == userId &&
                    !x.IsDeleted);

        if (notification == null)
        {
            throw new NotFoundException(
                "Notification not found.");
        }

        if (notification.IsRead)
        {
            return;
        }

        notification.IsRead = true;

        await _context.SaveChangesAsync();

        _logger.LogInformation(
    NotificationMarkedAsReadEvent,
    "Notification marked as read. Module: {Module}, UserId: {UserId}, NotificationId: {NotificationId}.",
    "Notifications",
    userId,
    notificationId);
    }

    public async Task MarkAllAsReadAsync(
        int userId)
    {
        var notifications =
            await _context.Notifications
                .Where(notification =>
                    notification.UserId == userId &&
                    !notification.IsDeleted &&
                    !notification.IsRead)
                .ToListAsync();

        if (notifications.Count == 0)
        {
            return;
        }

        foreach (var notification
                 in notifications)
        {
            notification.IsRead = true;
        }

        await _context.SaveChangesAsync();

        _logger.LogInformation(
            AllNotificationsMarkedAsReadEvent,
            "All unread notifications marked as read. Module: {Module}, UserId: {UserId}, NotificationCount: {NotificationCount}.",
            "Notifications",
            userId,
            notifications.Count);
    }

    private async Task
        ResolveActionAvailabilityAsync(
            int userId,
            List<NotificationResponseDto>
                notifications)
    {
        foreach (var notification
                 in notifications)
        {
            switch (ParseActionType(
                        notification.ActionType))
            {
                case NotificationActionType.None:
                case NotificationActionType.Payment:
                case NotificationActionType.Membership:
                case NotificationActionType.Review:
                case NotificationActionType.TherapistProfile:
                    notification.IsActionAvailable =
                        true;

                    break;

                case NotificationActionType.Appointment:
                case NotificationActionType.Chat:
                    await ResolveAppointmentActionAsync(
                        userId,
                        notification);

                    break;

                case NotificationActionType.Workshop:
                    await ResolveWorkshopActionAsync(
                        notification);

                    break;

                default:
                    notification.IsActionAvailable =
                        false;

                    notification.UnavailableReason =
                        "The linked resource is not available.";

                    break;
            }
        }
    }

    private async Task
        ResolveAppointmentActionAsync(
            int userId,
            NotificationResponseDto notification)
    {
        var appointmentId =
            notification.AppointmentId ??
            notification.ResourceId;

        if (!appointmentId.HasValue)
        {
            notification.IsActionAvailable =
                false;

            notification.UnavailableReason =
                "The linked appointment is not available.";

            return;
        }

        var isAvailable =
            await _context.Appointments
                .AsNoTracking()
                .AnyAsync(appointment =>
                    appointment.Id ==
                        appointmentId.Value &&
                    !appointment.IsDeleted &&
                    (
                        appointment.Client.UserId ==
                            userId ||
                        appointment.Therapist.UserId ==
                            userId
                    ));

        notification.IsActionAvailable =
            isAvailable;

        if (!isAvailable)
        {
            notification.UnavailableReason =
                "This appointment no longer exists or is not available to you.";
        }
    }

    private async Task
        ResolveWorkshopActionAsync(
            NotificationResponseDto notification)
    {
        if (!notification.ResourceId.HasValue)
        {
            notification.IsActionAvailable =
                false;

            notification.UnavailableReason =
                "The linked workshop is not available.";

            return;
        }

        var isAvailable =
            await _context.Workshops
                .AsNoTracking()
                .AnyAsync(workshop =>
                    workshop.Id ==
                        notification.ResourceId.Value &&
                    !workshop.IsDeleted);

        notification.IsActionAvailable =
            isAvailable;

        if (!isAvailable)
        {
            notification.UnavailableReason =
                "This workshop no longer exists or has been removed.";
        }
    }

    private static NotificationActionType
        ParseActionType(
            string actionType)
    {
        return Enum.TryParse<
                NotificationActionType>(
                actionType,
                true,
                out var parsed)
            ? parsed
            : NotificationActionType.None;
    }
}