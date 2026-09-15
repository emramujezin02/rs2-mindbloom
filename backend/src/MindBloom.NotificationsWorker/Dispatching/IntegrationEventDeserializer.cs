using System.Text.Json;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Articles;
using MindBloom.Messaging.Contracts.Chat;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Messaging.Contracts.Memberships;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.Messaging.Contracts.Reviews;
using MindBloom.Messaging.Contracts.Workshops;
using RoutingKeys =
    MindBloom.Messaging.Contracts.Common
        .IntegrationEventRoutingKeys;

namespace MindBloom.NotificationsWorker.Dispatching;

public sealed class IntegrationEventDeserializer
{
    private static readonly JsonSerializerOptions
        JsonOptions =
            new(JsonSerializerDefaults.Web)
            {
                PropertyNameCaseInsensitive =
                    true
            };

    public IntegrationEvent Deserialize(
        string routingKey,
        ReadOnlyMemory<byte> body)
    {
        if (string.IsNullOrWhiteSpace(
                routingKey))
        {
            throw new ArgumentException(
                "RabbitMQ routing key is required.",
                nameof(routingKey));
        }

        if (body.IsEmpty)
        {
            throw new JsonException(
                "Integration event body is empty.");
        }

        return routingKey switch
        {
            RoutingKeys.AppointmentCreated =>
                Deserialize<
                    AppointmentCreatedEvent>(
                    body),

            RoutingKeys.AppointmentAccepted =>
                Deserialize<
                    AppointmentAcceptedEvent>(
                    body),

            RoutingKeys.AppointmentRejected =>
                Deserialize<
                    AppointmentRejectedEvent>(
                    body),

            RoutingKeys.AppointmentCancelled =>
                Deserialize<
                    AppointmentCancelledEvent>(
                    body),

            RoutingKeys.AppointmentCompleted =>
                Deserialize<
                    AppointmentCompletedEvent>(
                    body),

            RoutingKeys.ChatMessageCreated =>
                Deserialize<
                    ChatMessageCreatedEvent>(
                    body),

            RoutingKeys.MembershipPurchased =>
                Deserialize<
                    MembershipPurchasedEvent>(
                    body),

            RoutingKeys.MembershipExpired =>
                Deserialize<
                    MembershipExpiredEvent>(
                    body),

            RoutingKeys.PaymentSucceeded =>
                Deserialize<
                    PaymentSucceededEvent>(
                    body),

            RoutingKeys.PaymentRefunded =>
                Deserialize<
                    PaymentRefundedEvent>(
                    body),

            RoutingKeys.WorkshopCreated =>
                Deserialize<
                    WorkshopCreatedEvent>(
                    body),

            RoutingKeys.WorkshopUpdated =>
                Deserialize<
                    WorkshopUpdatedEvent>(
                    body),

            RoutingKeys.WorkshopCancelled =>
                Deserialize<
                    WorkshopCancelledEvent>(
                    body),

            RoutingKeys.ArticlePublished =>
                Deserialize<
                    ArticlePublishedEvent>(
                    body),

            RoutingKeys.ReviewApproved =>
                Deserialize<
                    ReviewApprovedEvent>(
                    body),

            RoutingKeys.NotificationRequested =>
                Deserialize<
                    NotificationRequestedEvent>(
                    body),

            _ =>
                throw new NotSupportedException(
                    $"Integration event routing key "
                    + $"'{routingKey}' is not supported.")
        };
    }

    private static TEvent Deserialize<TEvent>(
        ReadOnlyMemory<byte> body)
        where TEvent : IntegrationEvent
    {
        var integrationEvent =
            JsonSerializer.Deserialize<TEvent>(
                body.Span,
                JsonOptions);

        if (integrationEvent == null)
        {
            throw new JsonException(
                $"Integration event "
                + $"'{typeof(TEvent).Name}' "
                + "could not be deserialized.");
        }

        ValidateBaseProperties(
            integrationEvent);

        return integrationEvent;
    }

    private static void ValidateBaseProperties(
        IntegrationEvent integrationEvent)
    {
        if (integrationEvent.EventId ==
            Guid.Empty)
        {
            throw new JsonException(
                "Integration event EventId is empty.");
        }

        if (integrationEvent.CorrelationId ==
            Guid.Empty)
        {
            throw new JsonException(
                "Integration event CorrelationId is empty.");
        }

        if (integrationEvent.TimestampUtc ==
            default)
        {
            throw new JsonException(
                "Integration event TimestampUtc is missing.");
        }

        if (integrationEvent.EventVersion < 1)
        {
            throw new JsonException(
                "Integration event EventVersion is invalid.");
        }
    }
}