using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Messaging;

public sealed class RabbitMqConsumerOperations
{
    private readonly ILogger<
        RabbitMqConsumerOperations>
        _logger;

    public RabbitMqConsumerOperations(
        ILogger<RabbitMqConsumerOperations>
            logger)
    {
        _logger =
            logger;
    }

    public async Task AcknowledgeAsync(
        IChannel channel,
        ulong deliveryTag,
        string consumerName)
    {
        ArgumentNullException.ThrowIfNull(
            channel);

        if (!channel.IsOpen)
        {
            throw new InvalidOperationException(
                $"RabbitMQ channel is not open for consumer '{consumerName}'.");
        }

        await channel.BasicAckAsync(
            deliveryTag:
                deliveryTag,
            multiple:
                false,
            cancellationToken:
                CancellationToken.None);

        _logger.LogDebug(
            "RabbitMQ message acknowledged. "
            + "Consumer: {Consumer}, "
            + "delivery tag: {DeliveryTag}.",
            consumerName,
            deliveryTag);
    }

    public async Task NegativeAcknowledgeAsync(
        IChannel channel,
        ulong deliveryTag,
        bool requeue,
        string consumerName)
    {
        ArgumentNullException.ThrowIfNull(
            channel);

        if (!channel.IsOpen)
        {
            throw new InvalidOperationException(
                $"RabbitMQ channel is not open for consumer '{consumerName}'.");
        }

        await channel.BasicNackAsync(
            deliveryTag:
                deliveryTag,
            multiple:
                false,
            requeue:
                requeue,
            cancellationToken:
                CancellationToken.None);

        _logger.LogWarning(
            "RabbitMQ message negatively acknowledged. "
            + "Consumer: {Consumer}, "
            + "delivery tag: {DeliveryTag}, "
            + "requeue: {Requeue}.",
            consumerName,
            deliveryTag,
            requeue);
    }

    public async Task PublishForwardedAsync(
        IChannel channel,
        string exchange,
        string routingKey,
        IReadOnlyBasicProperties
            originalProperties,
        ReadOnlyMemory<byte> body,
        int retryCount,
        string failureReason,
        string originalQueue,
        string consumerName)
    {
        ArgumentNullException.ThrowIfNull(
            channel);

        if (!channel.IsOpen)
        {
            throw new InvalidOperationException(
                $"RabbitMQ channel is not open for consumer '{consumerName}'.");
        }

        var properties =
            RabbitMqMessageHelper
                .CreateForwardProperties(
                    originalProperties,
                    retryCount,
                    failureReason,
                    originalQueue);

        await channel.BasicPublishAsync(
            exchange:
                exchange,
            routingKey:
                routingKey,
            mandatory:
                true,
            basicProperties:
                properties,
            body:
                body,
            cancellationToken:
                CancellationToken.None);

        _logger.LogDebug(
            "RabbitMQ message forwarded. "
            + "Consumer: {Consumer}, "
            + "exchange: {Exchange}, "
            + "routing key: {RoutingKey}, "
            + "retry count: {RetryCount}.",
            consumerName,
            exchange,
            routingKey,
            retryCount);
    }
}