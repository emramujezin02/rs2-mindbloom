using MindBloom.Domain.Enums;

namespace MindBloom.Application.Common.Interfaces;

public interface IBusinessNotificationService
{
    Task PublishAsync(
        int userId,
        string title,
        string message,
        int? appointmentId = null,
        NotificationActionType actionType =
            NotificationActionType.None,
        int? resourceId = null,
        bool sendEmail = false,
        bool sendPush = true,
        Guid? correlationId = null,
        CancellationToken cancellationToken =
            default);
}