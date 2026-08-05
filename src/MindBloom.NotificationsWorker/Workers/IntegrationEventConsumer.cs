using System.Text;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class IntegrationEventConsumer
    : BackgroundService,
      IAsyncDisposable
{
    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly RabbitMqTopology
        _topology;

    private readonly IntegrationEventDeserializer
        _deserializer;

    private readonly IIntegrationEventDispatcher
        _dispatcher;

    private readonly ILogger<
        IntegrationEventConsumer>
        _logger;

    private IConnection? _connection;

    private IChannel? _channel;

    private bool _disposed;

    public IntegrationEventConsumer(
        IOptions<RabbitMqOptions> options,
        RabbitMqConnectionFactory
            connectionFactory,
        RabbitMqTopology topology,
        IntegrationEventDeserializer
            deserializer,
        IIntegrationEventDispatcher
            dispatcher,
        ILogger<IntegrationEventConsumer>
            logger)
    {
        _options =
            options.Value;

        _connectionFactory =
            connectionFactory;

        _topology =
            topology;

        _deserializer =
            deserializer;

        _dispatcher =
            dispatcher;

        _logger =
            logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        try
        {
            await InitializeRabbitMqAsync(
                stoppingToken);

            var consumer =
                new AsyncEventingBasicConsumer(
                    _channel!);

            consumer.ReceivedAsync +=
                HandleMessageAsync;

            var consumerTag =
                await _channel!
                    .BasicConsumeAsync(
                        queue:
                            _options
                                .IntegrationEventQueue,

                        autoAck:
                            false,

                        consumer:
                            consumer,

                        cancellationToken:
                            stoppingToken);

            _logger.LogInformation(
                "Integration event consumer started. "
                + "Queue: {Queue}, consumer tag: "
                + "{ConsumerTag}.",
                _options.IntegrationEventQueue,
                consumerTag);

            await Task.Delay(
                Timeout.InfiniteTimeSpan,
                stoppingToken);
        }
        catch (OperationCanceledException)
            when (stoppingToken
                .IsCancellationRequested)
        {
            _logger.LogInformation(
                "Integration event consumer "
                + "is stopping.");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "Integration event consumer "
                + "could not be started.");

            throw;
        }
    }

    private async Task InitializeRabbitMqAsync(
        CancellationToken cancellationToken)
    {
        var factory =
            _connectionFactory.Create(
                _options.ConsumerClientName,
                consumerDispatchConcurrency: 1);

        _connection =
            await factory.CreateConnectionAsync(
                _options.ConsumerClientName,
                cancellationToken);

        _connection.ConnectionShutdownAsync +=
            OnConnectionShutdownAsync;

        _connection.ConnectionRecoveryErrorAsync +=
            OnConnectionRecoveryErrorAsync;

        _connection.RecoverySucceededAsync +=
            OnRecoverySucceededAsync;

        _channel =
            await _connection.CreateChannelAsync(
                cancellationToken:
                    cancellationToken);

        await _topology.DeclareAsync(
            _channel,
            cancellationToken);

        await _channel.BasicQosAsync(
            prefetchSize:
                0,

            prefetchCount:
                _options.PrefetchCount,

            global:
                false,

            cancellationToken:
                cancellationToken);

        _logger.LogInformation(
            "Integration event consumer "
            + "connected to RabbitMQ.");
    }

    private async Task HandleMessageAsync(
        object sender,
        BasicDeliverEventArgs eventArgs)
    {
        if (_channel is null ||
            !_channel.IsOpen)
        {
            _logger.LogError(
                "RabbitMQ channel is unavailable "
                + "for integration event delivery "
                + "{DeliveryTag}.",
                eventArgs.DeliveryTag);

            return;
        }

        var retryCount =
            GetRetryCount(
                eventArgs
                    .BasicProperties
                    .Headers);

        try
        {
            var integrationEvent =
                _deserializer.Deserialize(
                    eventArgs.RoutingKey,
                    eventArgs.Body);

            _logger.LogInformation(
                "Processing integration event "
                + "{EventType}. Routing key: "
                + "{RoutingKey}, attempt: "
                + "{Attempt}/{MaximumAttempts}.",
                integrationEvent
                    .GetType()
                    .Name,
                eventArgs.RoutingKey,
                retryCount + 1,
                _options.MaximumRetryCount + 1);

            await _dispatcher.DispatchAsync(
                integrationEvent,
                CancellationToken.None);

            await AcknowledgeAsync(
                eventArgs.DeliveryTag);
        }
        catch (NotSupportedException exception)
        {
            _logger.LogError(
                exception,
                "Unsupported integration event "
                + "with routing key {RoutingKey} "
                + "will be moved to DLQ.",
                eventArgs.RoutingKey);

            await MoveToDeadLetterQueueAsync(
                eventArgs,
                retryCount,
                exception.Message);
        }
        catch (System.Text.Json.JsonException
               exception)
        {
            _logger.LogError(
                exception,
                "Invalid integration event "
                + "with routing key {RoutingKey} "
                + "will be moved to DLQ.",
                eventArgs.RoutingKey);

            await MoveToDeadLetterQueueAsync(
                eventArgs,
                retryCount,
                exception.Message);
        }
        catch (ArgumentException exception)
        {
            _logger.LogError(
                exception,
                "Invalid integration event data "
                + "for routing key {RoutingKey} "
                + "will be moved to DLQ.",
                eventArgs.RoutingKey);

            await MoveToDeadLetterQueueAsync(
                eventArgs,
                retryCount,
                exception.Message);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Integration event processing "
                + "failed. Routing key: "
                + "{RoutingKey}, attempt: "
                + "{Attempt}.",
                eventArgs.RoutingKey,
                retryCount + 1);

            await HandleTransientFailureAsync(
                eventArgs,
                retryCount,
                exception);
        }
    }

    private async Task HandleTransientFailureAsync(
        BasicDeliverEventArgs eventArgs,
        int retryCount,
        Exception exception)
    {
        if (retryCount >=
            _options.MaximumRetryCount)
        {
            await MoveToDeadLetterQueueAsync(
                eventArgs,
                retryCount,
                exception.Message);

            return;
        }

        var delayIndex =
            Math.Min(
                retryCount,
                _topology.RetryDelays.Count - 1);

        var delayMilliseconds =
            _topology.RetryDelays[
                delayIndex];

        await Task.Delay(
            delayMilliseconds);

        var nextRetryCount =
            retryCount + 1;

        try
        {
            var properties =
                CreateForwardProperties(
                    eventArgs.BasicProperties,
                    nextRetryCount,
                    exception.Message);

            await _channel!
                .BasicPublishAsync(
                    exchange:
                        _options
                            .NotificationExchange,

                    routingKey:
                        eventArgs.RoutingKey,

                    mandatory:
                        true,

                    basicProperties:
                        properties,

                    body:
                        eventArgs.Body,

                    cancellationToken:
                        CancellationToken.None);

            await AcknowledgeAsync(
                eventArgs.DeliveryTag);

            _logger.LogWarning(
                "Integration event with routing "
                + "key {RoutingKey} was republished "
                + "for retry {RetryCount}/"
                + "{MaximumRetryCount} after "
                + "{DelayMilliseconds} ms.",
                eventArgs.RoutingKey,
                nextRetryCount,
                _options.MaximumRetryCount,
                delayMilliseconds);
        }
        catch (Exception publishException)
        {
            _logger.LogCritical(
                publishException,
                "Integration event retry publish "
                + "failed. Original message will "
                + "be requeued.");

            await NegativeAcknowledgeAsync(
                eventArgs.DeliveryTag,
                requeue: true);
        }
    }

    private async Task
        MoveToDeadLetterQueueAsync(
            BasicDeliverEventArgs eventArgs,
            int retryCount,
            string failureReason)
    {
        try
        {
            var properties =
                CreateForwardProperties(
                    eventArgs.BasicProperties,
                    retryCount,
                    failureReason);

            await _channel!
                .BasicPublishAsync(
                    exchange:
                        _options
                            .DeadLetterExchange,

                    routingKey:
                        _options
                            .IntegrationEventDeadLetterRoutingKey,

                    mandatory:
                        true,

                    basicProperties:
                        properties,

                    body:
                        eventArgs.Body,

                    cancellationToken:
                        CancellationToken.None);

            await AcknowledgeAsync(
                eventArgs.DeliveryTag);

            _logger.LogError(
                "Integration event with routing "
                + "key {RoutingKey} moved to "
                + "dead-letter queue {Queue}.",
                eventArgs.RoutingKey,
                _options
                    .IntegrationEventDeadLetterQueue);
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "Integration event could not be "
                + "moved to DLQ. Original message "
                + "will be requeued.");

            await NegativeAcknowledgeAsync(
                eventArgs.DeliveryTag,
                requeue: true);
        }
    }

    private BasicProperties
        CreateForwardProperties(
            IReadOnlyBasicProperties
                originalProperties,
            int retryCount,
            string failureReason)
    {
        var headers =
            CloneHeaders(
                originalProperties.Headers);

        headers[
            RabbitMqHeaders.RetryCount] =
                retryCount;

        headers[
            RabbitMqHeaders
                .LastFailureReason] =
                Truncate(
                    failureReason,
                    500);

        headers[
            RabbitMqHeaders
                .LastFailureAtUtc] =
                DateTime.UtcNow
                    .ToString("O");

        headers[
            RabbitMqHeaders
                .OriginalQueue] =
                _options
                    .IntegrationEventQueue;

        return new BasicProperties
        {
            Persistent =
                true,

            ContentType =
                originalProperties.ContentType
                ?? "application/json",

            ContentEncoding =
                originalProperties.ContentEncoding
                ?? "utf-8",

            MessageId =
                originalProperties.MessageId,

            CorrelationId =
                originalProperties.CorrelationId,

            Type =
                originalProperties.Type,

            AppId =
                originalProperties.AppId
                ?? "MindBloom.NotificationsWorker",

            Timestamp =
                originalProperties.Timestamp,

            Headers =
                headers
        };
    }

    private static Dictionary<string, object?>
        CloneHeaders(
            IDictionary<string, object?>?
                originalHeaders)
    {
        if (originalHeaders == null)
        {
            return new Dictionary<
                string,
                object?>();
        }

        return originalHeaders.ToDictionary(
            item => item.Key,
            item => item.Value);
    }

    private static int GetRetryCount(
        IDictionary<string, object?>? headers)
    {
        if (headers == null ||
            !headers.TryGetValue(
                RabbitMqHeaders.RetryCount,
                out var value) ||
            value == null)
        {
            return 0;
        }

        return value switch
        {
            byte byteValue =>
                byteValue,

            short shortValue =>
                shortValue,

            int intValue =>
                intValue,

            long longValue
                when longValue <=
                     int.MaxValue =>
                (int)longValue,

            byte[] bytes
                when int.TryParse(
                    Encoding.UTF8
                        .GetString(bytes),
                    out var parsedValue) =>
                parsedValue,

            string stringValue
                when int.TryParse(
                    stringValue,
                    out var parsedValue) =>
                parsedValue,

            _ => 0
        };
    }

    private async Task AcknowledgeAsync(
        ulong deliveryTag)
    {
        if (_channel is null ||
            !_channel.IsOpen)
        {
            throw new InvalidOperationException(
                "RabbitMQ channel is not "
                + "available for acknowledgment.");
        }

        await _channel.BasicAckAsync(
            deliveryTag:
                deliveryTag,

            multiple:
                false,

            cancellationToken:
                CancellationToken.None);
    }

    private async Task
        NegativeAcknowledgeAsync(
            ulong deliveryTag,
            bool requeue)
    {
        if (_channel is null ||
            !_channel.IsOpen)
        {
            return;
        }

        await _channel.BasicNackAsync(
            deliveryTag:
                deliveryTag,

            multiple:
                false,

            requeue:
                requeue,

            cancellationToken:
                CancellationToken.None);
    }

    private static string Truncate(
        string value,
        int maximumLength)
    {
        if (string.IsNullOrWhiteSpace(
                value))
        {
            return "Unknown failure.";
        }

        return value.Length <= maximumLength
            ? value
            : value[..maximumLength];
    }

    private Task OnConnectionShutdownAsync(
        object sender,
        ShutdownEventArgs eventArgs)
    {
        _logger.LogWarning(
            "RabbitMQ integration event "
            + "connection was shut down. "
            + "Reply code: {ReplyCode}. "
            + "Reason: {Reason}.",
            eventArgs.ReplyCode,
            eventArgs.ReplyText);

        return Task.CompletedTask;
    }

    private Task
        OnConnectionRecoveryErrorAsync(
            object sender,
            ConnectionRecoveryErrorEventArgs
                eventArgs)
    {
        _logger.LogError(
            eventArgs.Exception,
            "RabbitMQ integration event "
            + "connection recovery failed.");

        return Task.CompletedTask;
    }

    private Task OnRecoverySucceededAsync(
        object sender,
        AsyncEventArgs eventArgs)
    {
        _logger.LogInformation(
            "RabbitMQ integration event "
            + "connection recovery succeeded.");

        return Task.CompletedTask;
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();
    }

    private async Task
        DisposeRabbitMqResourcesAsync()
    {
        if (_channel is not null)
        {
            try
            {
                if (_channel.IsOpen)
                {
                    await _channel.CloseAsync(
                        cancellationToken:
                            CancellationToken.None);
                }
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    exception,
                    "Integration event channel "
                    + "could not be closed cleanly.");
            }

            await _channel.DisposeAsync();

            _channel =
                null;
        }

        if (_connection is not null)
        {
            try
            {
                if (_connection.IsOpen)
                {
                    await _connection.CloseAsync(
                        cancellationToken:
                            CancellationToken.None);
                }
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    exception,
                    "Integration event connection "
                    + "could not be closed cleanly.");
            }

            await _connection.DisposeAsync();

            _connection =
                null;
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }

        _disposed =
            true;

        await DisposeRabbitMqResourcesAsync();

        GC.SuppressFinalize(this);
    }
}