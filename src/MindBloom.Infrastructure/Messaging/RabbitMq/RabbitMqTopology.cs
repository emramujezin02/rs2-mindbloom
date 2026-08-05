using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MindBloom.Messaging.Contracts.Common;
using RabbitMQ.Client;
using static Azure.Core.HttpHeader;
using RoutingKeys =
    MindBloom.Messaging.Contracts.Common
        .IntegrationEventRoutingKeys;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;


namespace MindBloom.Infrastructure.Messaging.RabbitMq;

public sealed class RabbitMqTopology
{
    private static readonly int[]
        RetryDelaysMilliseconds =
        [
            1_000,
            2_000,
            4_000,
            8_000
        ];

    private static readonly string[]
        IntegrationEventRoutingKeys =
        [
            RoutingKeys.AppointmentCreated,
        RoutingKeys.AppointmentAccepted,
        RoutingKeys.AppointmentRejected,
        RoutingKeys.AppointmentCancelled,
        RoutingKeys.AppointmentCompleted,
        RoutingKeys.ChatMessageCreated,
        RoutingKeys.MembershipPurchased,
        RoutingKeys.MembershipExpired,
        RoutingKeys.PaymentSucceeded,
        RoutingKeys.PaymentRefunded,
        RoutingKeys.WorkshopCreated,
        RoutingKeys.WorkshopUpdated,
        RoutingKeys.WorkshopCancelled,
        RoutingKeys.ArticlePublished,
        RoutingKeys.ReviewApproved,
        RoutingKeys.NotificationRequested
        ];

    private readonly RabbitMqOptions
        _options;

    private readonly ILogger<RabbitMqTopology>
        _logger;

    public RabbitMqTopology(
        IOptions<RabbitMqOptions> options,
        ILogger<RabbitMqTopology> logger)
    {
        _options =
            options.Value;

        _logger =
            logger;
    }

    public IReadOnlyList<int> RetryDelays =>
        RetryDelaysMilliseconds;

    public IReadOnlyList<string>
        SupportedIntegrationEventRoutingKeys =>
            IntegrationEventRoutingKeys;

    public string GetRetryQueueName(
        string sourceQueue,
        int delayMilliseconds)
    {
        if (string.IsNullOrWhiteSpace(
                sourceQueue))
        {
            throw new ArgumentException(
                "RabbitMQ source queue is required.",
                nameof(sourceQueue));
        }

        return
            $"{sourceQueue}.retry.{delayMilliseconds}ms";
    }

    public string GetRetryRoutingKey(
        string sourceRoutingKey,
        int delayMilliseconds)
    {
        if (string.IsNullOrWhiteSpace(
                sourceRoutingKey))
        {
            throw new ArgumentException(
                "RabbitMQ source routing key is required.",
                nameof(sourceRoutingKey));
        }

        return
            $"{sourceRoutingKey}.retry.{delayMilliseconds}ms";
    }

    /*
     * Ove overload metode ostaju zbog postojećeg
     * EmailNotificationConsumer koda.
     */
    public string GetRetryQueueName(
        int delayMilliseconds)
    {
        return GetRetryQueueName(
            _options.EmailQueue,
            delayMilliseconds);
    }

    public string GetRetryRoutingKey(
        int delayMilliseconds)
    {
        return GetRetryRoutingKey(
            _options.EmailRoutingKey,
            delayMilliseconds);
    }

    public async Task DeclareAsync(
        IChannel channel,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(
            channel);

        await DeclareExchangesAsync(
            channel,
            cancellationToken);

        await DeclareEmailQueueAsync(
            channel,
            cancellationToken);

        await DeclareIntegrationEventQueueAsync(
            channel,
            cancellationToken);

        await DeclareEmailRetryQueuesAsync(
            channel,
            cancellationToken);

        await DeclareEmailDeadLetterQueueAsync(
            channel,
            cancellationToken);

        await DeclareIntegrationEventDeadLetterQueueAsync(
            channel,
            cancellationToken);

        _logger.LogInformation(
            "RabbitMQ topology declared. Exchange: {Exchange}, email queue: {EmailQueue}, integration queue: {IntegrationQueue}, email DLQ: {EmailDeadLetterQueue}, integration DLQ: {IntegrationDeadLetterQueue}.",
            _options.NotificationExchange,
            _options.EmailQueue,
            _options.IntegrationEventQueue,
            _options.DeadLetterQueue,
            _options.IntegrationEventDeadLetterQueue);
    }

    private async Task DeclareExchangesAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        await channel.ExchangeDeclareAsync(
            exchange:
                _options.NotificationExchange,
            type:
                ExchangeType.Direct,
            durable:
                true,
            autoDelete:
                false,
            arguments:
                null,
            cancellationToken:
                cancellationToken);

        await channel.ExchangeDeclareAsync(
            exchange:
                _options.RetryExchange,
            type:
                ExchangeType.Direct,
            durable:
                true,
            autoDelete:
                false,
            arguments:
                null,
            cancellationToken:
                cancellationToken);

        await channel.ExchangeDeclareAsync(
            exchange:
                _options.DeadLetterExchange,
            type:
                ExchangeType.Direct,
            durable:
                true,
            autoDelete:
                false,
            arguments:
                null,
            cancellationToken:
                cancellationToken);
    }

    private async Task DeclareEmailQueueAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        var arguments =
            new Dictionary<string, object?>
            {
                ["x-dead-letter-exchange"] =
                    _options.DeadLetterExchange,

                ["x-dead-letter-routing-key"] =
                    _options.DeadLetterRoutingKey
            };

        await channel.QueueDeclareAsync(
            queue:
                _options.EmailQueue,
            durable:
                true,
            exclusive:
                false,
            autoDelete:
                false,
            arguments:
                arguments,
            cancellationToken:
                cancellationToken);

        await channel.QueueBindAsync(
            queue:
                _options.EmailQueue,
            exchange:
                _options.NotificationExchange,
            routingKey:
                _options.EmailRoutingKey,
            arguments:
                null,
            cancellationToken:
                cancellationToken);
    }

    private async Task
        DeclareIntegrationEventQueueAsync(
            IChannel channel,
            CancellationToken cancellationToken)
    {
        var arguments =
            new Dictionary<string, object?>
            {
                ["x-dead-letter-exchange"] =
                    _options.DeadLetterExchange,

                ["x-dead-letter-routing-key"] =
                    _options
                        .IntegrationEventDeadLetterRoutingKey
            };

        await channel.QueueDeclareAsync(
            queue:
                _options.IntegrationEventQueue,
            durable:
                true,
            exclusive:
                false,
            autoDelete:
                false,
            arguments:
                arguments,
            cancellationToken:
                cancellationToken);

        foreach (var routingKey
                 in IntegrationEventRoutingKeys)
        {
            await channel.QueueBindAsync(
                queue:
                    _options.IntegrationEventQueue,
                exchange:
                    _options.NotificationExchange,
                routingKey:
                    routingKey,
                arguments:
                    null,
                cancellationToken:
                    cancellationToken);
        }

        _logger.LogInformation(
            "RabbitMQ integration event queue {Queue} bound to {RoutingKeyCount} routing keys.",
            _options.IntegrationEventQueue,
            IntegrationEventRoutingKeys.Length);
    }

    private async Task DeclareEmailRetryQueuesAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        foreach (var delayMilliseconds
                 in RetryDelaysMilliseconds)
        {
            var retryQueue =
                GetRetryQueueName(
                    _options.EmailQueue,
                    delayMilliseconds);

            var retryRoutingKey =
                GetRetryRoutingKey(
                    _options.EmailRoutingKey,
                    delayMilliseconds);

            var arguments =
                new Dictionary<string, object?>
                {
                    ["x-message-ttl"] =
                        delayMilliseconds,

                    ["x-dead-letter-exchange"] =
                        _options.NotificationExchange,

                    ["x-dead-letter-routing-key"] =
                        _options.EmailRoutingKey
                };

            await channel.QueueDeclareAsync(
                queue:
                    retryQueue,
                durable:
                    true,
                exclusive:
                    false,
                autoDelete:
                    false,
                arguments:
                    arguments,
                cancellationToken:
                    cancellationToken);

            await channel.QueueBindAsync(
                queue:
                    retryQueue,
                exchange:
                    _options.RetryExchange,
                routingKey:
                    retryRoutingKey,
                arguments:
                    null,
                cancellationToken:
                    cancellationToken);
        }
    }

    private async Task
        DeclareEmailDeadLetterQueueAsync(
            IChannel channel,
            CancellationToken cancellationToken)
    {
        await channel.QueueDeclareAsync(
            queue:
                _options.DeadLetterQueue,
            durable:
                true,
            exclusive:
                false,
            autoDelete:
                false,
            arguments:
                null,
            cancellationToken:
                cancellationToken);

        await channel.QueueBindAsync(
            queue:
                _options.DeadLetterQueue,
            exchange:
                _options.DeadLetterExchange,
            routingKey:
                _options.DeadLetterRoutingKey,
            arguments:
                null,
            cancellationToken:
                cancellationToken);
    }

    private async Task
        DeclareIntegrationEventDeadLetterQueueAsync(
            IChannel channel,
            CancellationToken cancellationToken)
    {
        await channel.QueueDeclareAsync(
            queue:
                _options
                    .IntegrationEventDeadLetterQueue,
            durable:
                true,
            exclusive:
                false,
            autoDelete:
                false,
            arguments:
                null,
            cancellationToken:
                cancellationToken);

        await channel.QueueBindAsync(
            queue:
                _options
                    .IntegrationEventDeadLetterQueue,
            exchange:
                _options.DeadLetterExchange,
            routingKey:
                _options
                    .IntegrationEventDeadLetterRoutingKey,
            arguments:
                null,
            cancellationToken:
                cancellationToken);
    }
}