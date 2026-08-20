using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.API.Messaging.Outbox;

public sealed class OutboxMessageProcessor
    : BackgroundService
{
    private static readonly EventId
        OutboxMessagePublishedEvent =
            new(
                3400,
                "OutboxMessagePublished");

    private static readonly EventId
        OutboxMessagePublishFailedEvent =
            new(
                3401,
                "OutboxMessagePublishFailed");

    private static readonly EventId
        OutboxMessageDeadLetteredEvent =
            new(
                3402,
                "OutboxMessageDeadLettered");

    private const int BatchSize =
        20;

    private const int MaximumAttempts =
        10;

    private static readonly TimeSpan
        PollingInterval =
            TimeSpan.FromSeconds(2);

    private static readonly JsonSerializerOptions
        JsonOptions =
            new(
                JsonSerializerDefaults.Web);

    private readonly IServiceScopeFactory
        _scopeFactory;

    private readonly ILogger<
        OutboxMessageProcessor>
        _logger;

    public OutboxMessageProcessor(
        IServiceScopeFactory scopeFactory,
        ILogger<OutboxMessageProcessor>
            logger)
    {
        _scopeFactory =
            scopeFactory;

        _logger =
            logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        while (!stoppingToken
                   .IsCancellationRequested)
        {
            try
            {
                var processedAny =
                    await ProcessBatchAsync(
                        stoppingToken);

                if (!processedAny)
                {
                    await Task.Delay(
                        PollingInterval,
                        stoppingToken);
                }
            }
            catch (OperationCanceledException)
                when (stoppingToken
                    .IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    OutboxMessagePublishFailedEvent,
                    exception,
                    "Outbox processing cycle failed. "
                    + "Module: {Module}.",
                    "Outbox");

                await Task.Delay(
                    PollingInterval,
                    stoppingToken);
            }
        }
    }

    private async Task<bool> ProcessBatchAsync(
        CancellationToken cancellationToken)
    {
        using var scope =
            _scopeFactory.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var publisher =
            scope.ServiceProvider
                .GetRequiredService<
                    IIntegrationEventPublisher>();

        var now =
            DateTime.UtcNow;

        var messages =
            await context.OutboxMessages
                .Where(message =>
                    message.ProcessedAtUtc == null &&
                    !message.IsDeadLettered &&
                    (
                        message.NextAttemptAtUtc ==
                            null ||
                        message.NextAttemptAtUtc <=
                            now
                    ))
                .OrderBy(message =>
                    message.CreatedAtUtc)
                .ThenBy(message =>
                    message.Id)
                .Take(BatchSize)
                .ToListAsync(
                    cancellationToken);

        if (messages.Count == 0)
        {
            return false;
        }

        foreach (var message in messages)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            try
            {
                var eventType =
                    Type.GetType(
                        message.EventType,
                        throwOnError:
                            false);

                if (eventType == null ||
                    !typeof(IntegrationEvent)
                        .IsAssignableFrom(
                            eventType))
                {
                    throw new InvalidOperationException(
                        "Outbox integration event type could not be resolved.");
                }

                var integrationEvent =
                    JsonSerializer.Deserialize(
                        message.PayloadJson,
                        eventType,
                        JsonOptions)
                    as IntegrationEvent;

                if (integrationEvent == null)
                {
                    throw new InvalidOperationException(
                        "Outbox integration event payload could not be deserialized.");
                }

                await publisher.PublishAsync(
                    integrationEvent,
                    message.RoutingKey,
                    cancellationToken);

                message.ProcessedAtUtc =
                    DateTime.UtcNow;

                message.LastAttemptAtUtc =
                    DateTime.UtcNow;

                message.LastError =
                    null;

                message.NextAttemptAtUtc =
                    null;

                await context
                    .SaveChangesAsync(
                        cancellationToken);

                _logger.LogInformation(
                    OutboxMessagePublishedEvent,
                    "Outbox message published successfully. "
                    + "Module: {Module}, "
                    + "OutboxMessageId: {OutboxMessageId}, "
                    + "EventId: {IntegrationEventId}, "
                    + "EventType: {EventType}, "
                    + "AttemptCount: {AttemptCount}.",
                    "Outbox",
                    message.Id,
                    message.EventId,
                    integrationEvent
                        .GetType()
                        .Name,
                    message.AttemptCount);
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                message.AttemptCount +=
                    1;

                message.LastAttemptAtUtc =
                    DateTime.UtcNow;

                message.LastError =
                    CreateSafeError(
                        exception);

                if (message.AttemptCount >=
                    MaximumAttempts)
                {
                    message.IsDeadLettered =
                        true;

                    message.NextAttemptAtUtc =
                        null;

                    _logger.LogError(
                        OutboxMessageDeadLetteredEvent,
                        exception,
                        "Outbox message moved to failed state after maximum attempts. "
                        + "Module: {Module}, "
                        + "OutboxMessageId: {OutboxMessageId}, "
                        + "EventId: {IntegrationEventId}, "
                        + "AttemptCount: {AttemptCount}.",
                        "Outbox",
                        message.Id,
                        message.EventId,
                        message.AttemptCount);
                }
                else
                {
                    message.NextAttemptAtUtc =
                        DateTime.UtcNow.Add(
                            CalculateRetryDelay(
                                message
                                    .AttemptCount));

                    _logger.LogWarning(
                        OutboxMessagePublishFailedEvent,
                        exception,
                        "Outbox publish attempt failed and will be retried. "
                        + "Module: {Module}, "
                        + "OutboxMessageId: {OutboxMessageId}, "
                        + "EventId: {IntegrationEventId}, "
                        + "Attempt: {Attempt}, "
                        + "MaximumAttempts: {MaximumAttempts}.",
                        "Outbox",
                        message.Id,
                        message.EventId,
                        message.AttemptCount,
                        MaximumAttempts);
                }

                await context
                    .SaveChangesAsync(
                        cancellationToken);
            }
        }

        return true;
    }

    private static TimeSpan
        CalculateRetryDelay(
            int attempt)
    {
        var seconds =
            Math.Min(
                Math.Pow(
                    2,
                    Math.Max(
                        0,
                        attempt - 1)),
                60);

        return TimeSpan.FromSeconds(
            seconds);
    }

    private static string CreateSafeError(
        Exception exception)
    {
        var value =
            exception
                .GetType()
                .Name
            + ": "
            + exception.Message;

        const int maximumLength =
            2000;

        return value.Length <=
               maximumLength
            ? value
            : value[..maximumLength];
    }
}