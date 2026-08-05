namespace MindBloom.Messaging.Contracts.Common;

public static class IntegrationEventRoutingKeys
{
    public const string AppointmentCreated =
        "appointment.created";

    public const string AppointmentAccepted =
        "appointment.accepted";

    public const string AppointmentRejected =
        "appointment.rejected";

    public const string AppointmentCancelled =
        "appointment.cancelled";

    public const string AppointmentCompleted =
        "appointment.completed";

    public const string ChatMessageCreated =
        "chat.message-created";

    public const string MembershipPurchased =
        "membership.purchased";

    public const string MembershipExpired =
        "membership.expired";

    public const string PaymentSucceeded =
        "payment.succeeded";

    public const string PaymentRefunded =
        "payment.refunded";

    public const string WorkshopCreated =
        "workshop.created";

    public const string WorkshopUpdated =
        "workshop.updated";

    public const string WorkshopCancelled =
        "workshop.cancelled";

    public const string ArticlePublished =
        "article.published";

    public const string ReviewApproved =
        "review.approved";

    public const string NotificationRequested =
        "notification.requested";
}