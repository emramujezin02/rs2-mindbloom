using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.NotificationsWorker.Services;

public sealed class ProcessedMessageService
{
    private readonly ApplicationDbContext
        _context;

    private readonly ILogger<
        ProcessedMessageService>
        _logger;

    public ProcessedMessageService(
        ApplicationDbContext context,
        ILogger<ProcessedMessageService>
            logger)
    {
        _context =
            context;

        _logger =
            logger;
    }

    public async Task<bool> IsProcessedAsync(
        Guid messageId,
        string consumerName,
        CancellationToken cancellationToken =
            default)
    {
        Validate(
            messageId,
            consumerName);

        return await _context
            .ProcessedMessages
            .AsNoTracking()
            .AnyAsync(
                processedMessage =>
                    processedMessage.MessageId ==
                        messageId &&
                    processedMessage.ConsumerName ==
                        consumerName,
                cancellationToken);
    }

    public async Task MarkAsProcessedAsync(
        Guid messageId,
        string consumerName,
        string messageType,
        Guid? correlationId = null,
        CancellationToken cancellationToken =
            default)
    {
        Validate(
            messageId,
            consumerName);

        var normalizedMessageType =
            messageType?.Trim()
            ?? string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedMessageType))
        {
            throw new ArgumentException(
                "Processed message type is required.",
                nameof(messageType));
        }

        var alreadyProcessed =
            await IsProcessedAsync(
                messageId,
                consumerName,
                cancellationToken);

        if (alreadyProcessed)
        {
            _logger.LogInformation(
                "Message {MessageId} was already marked "
                + "as processed by consumer {ConsumerName}.",
                messageId,
                consumerName);

            return;
        }

        var processedMessage =
            new ProcessedMessage
            {
                MessageId =
                    messageId,

                ConsumerName =
                    consumerName.Trim(),

                MessageType =
                    normalizedMessageType,

                CorrelationId =
                    correlationId,

                ProcessedAtUtc =
                    DateTime.UtcNow
            };

        _context.ProcessedMessages.Add(
            processedMessage);

        await _context.SaveChangesAsync(
            cancellationToken);

        _logger.LogInformation(
            "Message {MessageId} marked as processed. "
            + "Consumer: {ConsumerName}, "
            + "message type: {MessageType}.",
            messageId,
            consumerName,
            normalizedMessageType);
    }

    private static void Validate(
        Guid messageId,
        string consumerName)
    {
        if (messageId == Guid.Empty)
        {
            throw new ArgumentException(
                "Message identifier cannot be empty.",
                nameof(messageId));
        }

        if (string.IsNullOrWhiteSpace(
                consumerName))
        {
            throw new ArgumentException(
                "Consumer name is required.",
                nameof(consumerName));
        }
    }
}