using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.NotificationsWorker.Services;

public sealed class WorkerNotificationService
{
    private readonly ApplicationDbContext
        _context;

    private readonly IEmailService
        _emailService;

    private readonly IPushNotificationService
    _pushNotificationService;

    private readonly ILogger<
        WorkerNotificationService>
        _logger;

    public WorkerNotificationService(
        ApplicationDbContext context,
        IEmailService emailService,
        IPushNotificationService pushNotificationService,
        ILogger<WorkerNotificationService> logger)
    {
        _context =
            context;

        _emailService =
            emailService;

        _pushNotificationService =
            pushNotificationService;

        _logger =
            logger;
    }

    public async Task CreateAsync(
        int userId,
        string title,
        string message,
        NotificationActionType actionType,
        int? appointmentId = null,
        int? resourceId = null,
        CancellationToken cancellationToken =
            default)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "Notification user identifier is invalid.",
                nameof(userId));
        }

        var normalizedTitle =
            title?.Trim() ??
            string.Empty;

        var normalizedMessage =
            message?.Trim() ??
            string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedTitle))
        {
            throw new ArgumentException(
                "Notification title is required.",
                nameof(title));
        }

        if (string.IsNullOrWhiteSpace(
                normalizedMessage))
        {
            throw new ArgumentException(
                "Notification message is required.",
                nameof(message));
        }

        var notification =
            new Notification
            {
                UserId =
                    userId,

                Title =
                    normalizedTitle,

                Message =
                    normalizedMessage,

                AppointmentId =
                    appointmentId,

                ResourceId =
                    resourceId,

                ActionType =
                    actionType,

                IsRead =
                    false,

                SentAtUtc =
                    DateTime.UtcNow
            };

        _context.Notifications.Add(
            notification);

        await _context.SaveChangesAsync(
            cancellationToken);

        _logger.LogInformation(
            "In-app notification {NotificationId} created for user {UserId}.",
            notification.Id,
            userId);
    }

    public async Task SendEmailAsync(
        int userId,
        string subject,
        string message,
        CancellationToken cancellationToken =
            default)
    {
        var user =
            await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    currentUser =>
                        currentUser.Id ==
                            userId,
                    cancellationToken);

        if (user == null)
        {
            throw new InvalidOperationException(
                $"User {userId} was not found.");
        }

        if (string.IsNullOrWhiteSpace(
                user.Email))
        {
            _logger.LogWarning(
                "Email notification was skipped because user {UserId} does not have an email address.",
                userId);

            return;
        }

        await _emailService.SendAsync(
            user.Email,
            subject,
            message);
    }

    public async Task NotifyAsync(
      int userId,
      string title,
      string message,
      NotificationActionType actionType,
      int? appointmentId = null,
      int? resourceId = null,
      bool sendEmail = true,
      bool sendPush = true,
      CancellationToken cancellationToken =
          default)
    {
        await CreateAsync(
            userId,
            title,
            message,
            actionType,
            appointmentId,
            resourceId,
            cancellationToken);

        if (sendEmail)
        {
            await SendEmailAsync(
                userId,
                title,
                message,
                cancellationToken);
        }

        if (sendPush)
        {
            var data =
                new Dictionary<string, string>
                {
                    ["actionType"] =
                        actionType.ToString()
                };

            if (appointmentId.HasValue)
            {
                data["appointmentId"] =
                    appointmentId.Value
                        .ToString();
            }

            if (resourceId.HasValue)
            {
                data["resourceId"] =
                    resourceId.Value
                        .ToString();
            }

            await _pushNotificationService
                .SendToUserAsync(
                    userId,
                    title,
                    message,
                    data,
                    cancellationToken);
        }
    }
}