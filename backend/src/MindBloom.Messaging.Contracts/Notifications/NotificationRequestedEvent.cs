using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Notifications;

public sealed record NotificationRequestedEvent
    : IntegrationEvent
{
    public required int UserId { get; init; }

    public required string Title { get; init; }

    public required string Message { get; init; }

    public int? AppointmentId { get; init; }

    public required string ActionType { get; init; }

    public int? ResourceId { get; init; }

    public int? NotificationId { get; init; }

    public bool SendEmail { get; init; }

    public bool SendPush { get; init; } =
    true;
}