using System.Text;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using MindBloom.NotificationsWorker.Services;

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

    private readonly IServiceScopeFactory
    _scopeFactory;

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
        IServiceScopeFactory scopeFactory,
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

        _scopeFactory =
    scopeFactory;
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
        _connection =
            await CreateConnectionWithRetryAsync(
                cancellationToken);

        SubscribeToConnectionEvents(
            _connection);

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
            "Integration event consumer connected to RabbitMQ successfully. "
            + "Queue: {Queue}, prefetch count: {PrefetchCount}.",
            _options.IntegrationEventQueue,
            _options.PrefetchCount);
    }

    private async Task<IConnection>
    CreateConnectionWithRetryAsync(
        CancellationToken cancellationToken)
    {
        var factory =
            _connectionFactory.Create(
                _options.ConsumerClientName,
                consumerDispatchConcurrency: 1);

        Exception? lastException =
            null;

        for (var attempt = 1;
             attempt <=
             _options.ConnectionRetryCount;
             attempt++)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            try
            {
                _logger.LogInformation(
                    "Connecting integration event consumer to RabbitMQ at "
                    + "{HostName}:{Port}. Attempt {Attempt}/{MaximumAttempts}.",
                    _options.HostName,
                    _options.Port,
                    attempt,
                    _options.ConnectionRetryCount);

                var connection =
                    await factory
                        .CreateConnectionAsync(
                            _options.ConsumerClientName,
                            cancellationToken);

                _logger.LogInformation(
                    "Integration event consumer RabbitMQ connection "
                    + "established successfully.");

                return connection;
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                lastException =
                    exception;

                _logger.LogWarning(
                    exception,
                    "Integration event consumer RabbitMQ connection "
                    + "attempt {Attempt}/{MaximumAttempts} failed.",
                    attempt,
                    _options.ConnectionRetryCount);

                if (attempt >=
                    _options.ConnectionRetryCount)
                {
                    break;
                }

                await Task.Delay(
                    TimeSpan.FromSeconds(
                        _options
                            .ConnectionRetryDelaySeconds),
                    cancellationToken);
            }
        }

        throw new InvalidOperationException(
            "Integration event consumer could not establish "
            + "a RabbitMQ connection after all configured retry attempts.",
            lastException);
    }

    private void SubscribeToConnectionEvents(
    IConnection connection)
    {
        connection.ConnectionShutdownAsync +=
            OnConnectionShutdownAsync;

        connection.ConnectionRecoveryErrorAsync +=
            OnConnectionRecoveryErrorAsync;

        connection.RecoverySucceededAsync +=
            OnRecoverySucceededAsync;
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

            var consumerName =
                nameof(IntegrationEventConsumer);

            using var scope =
                _scopeFactory.CreateScope();

            var processedMessageService =
                scope.ServiceProvider
                    .GetRequiredService<
                        ProcessedMessageService>();

            var alreadyProcessed =
                await processedMessageService
                    .IsProcessedAsync(
                        integrationEvent.EventId,
                        consumerName,
                        CancellationToken.None);

            if (alreadyProcessed)
            {
                _logger.LogWarning(
                    "Duplicate integration event detected. "
                    + "Event ID: {EventId}, "
                    + "event type: {EventType}, "
                    + "routing key: {RoutingKey}. "
                    + "Message will be acknowledged without processing.",
                    integrationEvent.EventId,
                    integrationEvent
                        .GetType()
                        .Name,
                    eventArgs.RoutingKey);

                await AcknowledgeAsync(
                    eventArgs.DeliveryTag);

                return;
            }

            _logger.LogInformation(
                "Processing integration event "
                + "{EventType}. Routing key: "
                + "{RoutingKey}, attempt: "
                + "{Attempt}/{MaximumAttempts}. "
                + "Event ID: {EventId}.",
                integrationEvent
                    .GetType()
                    .Name,
                eventArgs.RoutingKey,
                retryCount + 1,
                _options.MaximumRetryCount + 1,
                integrationEvent.EventId);

            await _dispatcher.DispatchAsync(
                integrationEvent,
                CancellationToken.None);

            await processedMessageService
                .MarkAsProcessedAsync(
                    integrationEvent.EventId,
                    consumerName,
                    integrationEvent
                        .GetType()
                        .Name,
                    integrationEvent.CorrelationId,
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
            _logger.LogError(
                "Integration event with routing key {RoutingKey} exhausted all {MaximumAttempts} attempts and will be moved to DLQ.",
                eventArgs.RoutingKey,
                _options.MaximumRetryCount + 1);

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

        var nextRetryCount =
            retryCount + 1;

        var retryRoutingKey =
            _topology.GetRetryRoutingKey(
                eventArgs.RoutingKey,
                delayMilliseconds);

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
                        _options.RetryExchange,

                    routingKey:
                        retryRoutingKey,

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
                "Integration event with routing key {RoutingKey} scheduled for retry {RetryCount}/{MaximumRetryCount} after {DelayMilliseconds} ms.",
                eventArgs.RoutingKey,
                nextRetryCount,
                _options.MaximumRetryCount,
                delayMilliseconds);
        }
        catch (Exception publishException)
        {
            _logger.LogCritical(
                publishException,
                "Integration event with routing key {RoutingKey} could not be published to retry exchange. Original delivery will be requeued.",
                eventArgs.RoutingKey);

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
                "Integration event moved to DLQ. "
                + "RoutingKey: {RoutingKey}, "
                + "MessageId: {MessageId}, "
                + "CorrelationId: {CorrelationId}, "
                + "Queue: {DeadLetterQueue}, "
                + "RetryCount: {RetryCount}, "
                + "FailureReason: {FailureReason}.",
                eventArgs.RoutingKey,
                eventArgs.BasicProperties
                    .MessageId,
                eventArgs.BasicProperties
                    .CorrelationId,
                _options
                    .IntegrationEventDeadLetterQueue,
                retryCount,
                Truncate(
                    failureReason,
                    500));
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
        _logger.LogInformation(
            "Stopping integration event consumer.");

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();

        _logger.LogInformation(
            "Integration event consumer stopped successfully.");
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