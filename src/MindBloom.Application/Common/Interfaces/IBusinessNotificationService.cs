namespace MindBloom.Application.Common.Interfaces;

public interface IBusinessNotificationService
{
    Task PublishAsync(
        int userId,
        string title,
        string message,
        int? appointmentId = null);
}