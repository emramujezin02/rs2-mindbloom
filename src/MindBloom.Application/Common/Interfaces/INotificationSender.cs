namespace MindBloom.Application.Common.Interfaces;

public interface INotificationSender
{
    Task SendToUserAsync(
        int userId,
        string title,
        string message);
}