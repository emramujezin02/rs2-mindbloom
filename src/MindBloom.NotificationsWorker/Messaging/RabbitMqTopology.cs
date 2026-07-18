using MindBloom.NotificationsWorker.Configuration;
using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Messaging;

public sealed class RabbitMqTopology
{
    private static readonly int[] RetryDelaysMilliseconds =
    [
        1_000,
        2_000,
        4_000,
        8_000
    ];

    private readonly RabbitMqConsumerOptions _options;
    private readonly ILogger<RabbitMqTopology> _logger;

    public RabbitMqTopology(
        RabbitMqConsumerOptions options,
        ILogger<RabbitMqTopology> logger)
    {
        _options = options;
        _logger = logger;
    }

    public IReadOnlyList<int> RetryDelays =>
        RetryDelaysMilliseconds;

    public async Task DeclareAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        await DeclareExchangesAsync(
            channel,
            cancellationToken);

        await DeclareMainQueueAsync(
            channel,
            cancellationToken);

        await DeclareRetryQueuesAsync(
            channel,
            cancellationToken);

        await DeclareDeadLetterQueueAsync(
            channel,
            cancellationToken);

        _logger.LogInformation(
            "RabbitMQ notification topology declared. Main queue: {MainQueue}, retry exchange: {RetryExchange}, DLQ: {DeadLetterQueue}.",
            _options.EmailQueue,
            _options.RetryExchange,
            _options.DeadLetterQueue);
    }

    public string GetRetryQueueName(
        int delayMilliseconds)
    {
        return
            $"{_options.EmailQueue}.retry.{delayMilliseconds}ms";
    }

    public string GetRetryRoutingKey(
        int delayMilliseconds)
    {
        return
            $"{_options.EmailRoutingKey}.retry.{delayMilliseconds}ms";
    }

    private async Task DeclareExchangesAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        await channel.ExchangeDeclareAsync(
            exchange: _options.NotificationExchange,
            type: ExchangeType.Direct,
            durable: true,
            autoDelete: false,
            arguments: null,
            cancellationToken: cancellationToken);

        await channel.ExchangeDeclareAsync(
            exchange: _options.RetryExchange,
            type: ExchangeType.Direct,
            durable: true,
            autoDelete: false,
            arguments: null,
            cancellationToken: cancellationToken);

        await channel.ExchangeDeclareAsync(
            exchange: _options.DeadLetterExchange,
            type: ExchangeType.Direct,
            durable: true,
            autoDelete: false,
            arguments: null,
            cancellationToken: cancellationToken);
    }

    private async Task DeclareMainQueueAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        /*
         * Ako poruka iz glavnog reda bude rejectovana bez requeue,
         * RabbitMQ je šalje u dead-letter exchange.
         */
        var arguments = new Dictionary<string, object?>
        {
            ["x-dead-letter-exchange"] =
                _options.DeadLetterExchange,

            ["x-dead-letter-routing-key"] =
                _options.DeadLetterRoutingKey
        };

        await channel.QueueDeclareAsync(
            queue: _options.EmailQueue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: arguments,
            cancellationToken: cancellationToken);

        await channel.QueueBindAsync(
            queue: _options.EmailQueue,
            exchange: _options.NotificationExchange,
            routingKey: _options.EmailRoutingKey,
            arguments: null,
            cancellationToken: cancellationToken);
    }

    private async Task DeclareRetryQueuesAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        foreach (var delayMilliseconds in RetryDelaysMilliseconds)
        {
            var retryQueue =
                GetRetryQueueName(delayMilliseconds);

            var retryRoutingKey =
                GetRetryRoutingKey(delayMilliseconds);

            /*
             * Poruka ostaje u retry redu onoliko koliko određuje
             * x-message-ttl.
             *
             * Nakon isteka TTL-a RabbitMQ je automatski vraća na
             * glavni notification exchange i email routing key.
             */
            var arguments = new Dictionary<string, object?>
            {
                ["x-message-ttl"] = delayMilliseconds,

                ["x-dead-letter-exchange"] =
                    _options.NotificationExchange,

                ["x-dead-letter-routing-key"] =
                    _options.EmailRoutingKey
            };

            await channel.QueueDeclareAsync(
                queue: retryQueue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: arguments,
                cancellationToken: cancellationToken);

            await channel.QueueBindAsync(
                queue: retryQueue,
                exchange: _options.RetryExchange,
                routingKey: retryRoutingKey,
                arguments: null,
                cancellationToken: cancellationToken);

            _logger.LogInformation(
                "RabbitMQ retry queue {RetryQueue} declared with delay of {DelayMilliseconds} ms.",
                retryQueue,
                delayMilliseconds);
        }
    }

    private async Task DeclareDeadLetterQueueAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        await channel.QueueDeclareAsync(
            queue: _options.DeadLetterQueue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: null,
            cancellationToken: cancellationToken);

        await channel.QueueBindAsync(
            queue: _options.DeadLetterQueue,
            exchange: _options.DeadLetterExchange,
            routingKey: _options.DeadLetterRoutingKey,
            arguments: null,
            cancellationToken: cancellationToken);
    }
}