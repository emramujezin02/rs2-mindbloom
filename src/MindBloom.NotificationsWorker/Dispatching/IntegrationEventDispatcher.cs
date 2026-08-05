using Microsoft.Extensions.DependencyInjection;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Articles;
using MindBloom.Messaging.Contracts.Chat;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Messaging.Contracts.Memberships;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.Messaging.Contracts.Reviews;
using MindBloom.Messaging.Contracts.Workshops;
using MindBloom.NotificationsWorker.Handlers;

namespace MindBloom.NotificationsWorker.Dispatching;

public sealed class IntegrationEventDispatcher
    : IIntegrationEventDispatcher
{
    private readonly IServiceScopeFactory
        _scopeFactory;

    private readonly ILogger<
        IntegrationEventDispatcher>
        _logger;

    public IntegrationEventDispatcher(
        IServiceScopeFactory scopeFactory,
        ILogger<IntegrationEventDispatcher>
            logger)
    {
        _scopeFactory =
            scopeFactory;

        _logger =
            logger;
    }

    public Task DispatchAsync(
        IntegrationEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(
            integrationEvent);

        return integrationEvent switch
        {
            AppointmentCreatedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            AppointmentAcceptedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            AppointmentRejectedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            AppointmentCancelledEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            AppointmentCompletedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            ChatMessageCreatedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            MembershipPurchasedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            MembershipExpiredEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            PaymentSucceededEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            PaymentRefundedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            WorkshopCreatedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            WorkshopUpdatedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            WorkshopCancelledEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            ArticlePublishedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            ReviewApprovedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            NotificationRequestedEvent value =>
                DispatchTypedAsync(
                    value,
                    cancellationToken),

            _ =>
                throw new NotSupportedException(
                    $"Integration event type "
                    + $"'{integrationEvent.GetType().Name}' "
                    + "is not supported.")
        };
    }

    private async Task DispatchTypedAsync<TEvent>(
        TEvent integrationEvent,
        CancellationToken cancellationToken)
        where TEvent : IntegrationEvent
    {
        using var scope =
            _scopeFactory.CreateScope();

        var handler =
            scope.ServiceProvider
                .GetRequiredService<
                    IIntegrationEventHandler<
                        TEvent>>();

        _logger.LogInformation(
            "Dispatching integration event "
            + "{EventType}. Event ID: {EventId}, "
            + "correlation ID: {CorrelationId}, "
            + "version: {EventVersion}.",
            typeof(TEvent).Name,
            integrationEvent.EventId,
            integrationEvent.CorrelationId,
            integrationEvent.EventVersion);

        await handler.HandleAsync(
            integrationEvent,
            cancellationToken);

        _logger.LogInformation(
            "Integration event {EventType} "
            + "processed successfully. "
            + "Event ID: {EventId}.",
            typeof(TEvent).Name,
            integrationEvent.EventId);
    }
}