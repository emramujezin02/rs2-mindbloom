using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Domain.Enums;

namespace MindBloom.Infrastructure.Messaging.Outbox;

public sealed class OutboxWriter
    : IOutboxWriter
{
    private static readonly JsonSerializerOptions
        JsonOptions =
            new(
                JsonSerializerDefaults.Web)
            {
                WriteIndented =
                    false
            };

    private readonly ApplicationDbContext
        _context;
    private readonly ICorrelationIdAccessor
    _correlationIdAccessor;

    public OutboxWriter(
        ApplicationDbContext context,
        ICorrelationIdAccessor
            correlationIdAccessor)
    {
        _context =
            context;

        _correlationIdAccessor =
            correlationIdAccessor;
    }

    public async Task EnqueueAsync<TEvent>(
        TEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken =
            default,
        string? idempotencyKey =
            null)
            where TEvent : IntegrationEvent
    {
        ArgumentNullException.ThrowIfNull(
            integrationEvent);

        var currentCorrelationId =
    _correlationIdAccessor
        .CorrelationId;

        if (!string.IsNullOrWhiteSpace(
                currentCorrelationId) &&
            Guid.TryParse(
                currentCorrelationId,
                out var parsedCorrelationId))
        {
            integrationEvent.CorrelationId =
                parsedCorrelationId;
        }

        if (string.IsNullOrWhiteSpace(
                routingKey))
        {
            throw new ArgumentException(
                "Outbox routing key is required.",
                nameof(routingKey));
        }

        if (integrationEvent.EventId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "Integration event EventId cannot be empty.",
                nameof(integrationEvent));
        }

        if (integrationEvent.CorrelationId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "Integration event CorrelationId cannot be empty.",
                nameof(integrationEvent));
        }

        var eventType =
            integrationEvent
                .GetType();

        var assemblyQualifiedName =
            eventType
                .AssemblyQualifiedName;

        if (string.IsNullOrWhiteSpace(
                assemblyQualifiedName))
        {
            throw new InvalidOperationException(
                "Integration event type could not be resolved.");
        }


        var normalizedIdempotencyKey =
string.IsNullOrWhiteSpace(
idempotencyKey)
? null
: idempotencyKey.Trim();

        if (normalizedIdempotencyKey is not null)
        {
            var alreadyExists =
                await _context.OutboxMessages
                    .AnyAsync(
                        x =>
                            x.IdempotencyKey ==
                            normalizedIdempotencyKey,
                        cancellationToken);

            if (alreadyExists)
            {
                return;
            }
        }
        var payload =
            JsonSerializer.Serialize(
                integrationEvent,
                eventType,
                JsonOptions);

        var outboxMessage =
            new OutboxMessage
            {
                EventId =
                    integrationEvent.EventId,

                CorrelationId =
                    integrationEvent
                        .CorrelationId,

                EventType =
                    assemblyQualifiedName,

                RoutingKey =
                    routingKey.Trim(),

                IdempotencyKey =
    normalizedIdempotencyKey,

                PayloadJson =
                    payload,

                OccurredAtUtc =
                    integrationEvent
                        .TimestampUtc,

                CreatedAtUtc =
                    DateTime.UtcNow,

                AttemptCount =
                    0,

                IsDeadLettered =
                    false,

                Status =
    OutboxMessageStatus.Pending,
            };



        _context.OutboxMessages.Add(
            outboxMessage);
    }
}