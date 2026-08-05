using System.Text;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Monitoring;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class IntegrationEventConsumer
    : BackgroundService,
      IAsyncDisposable
{
    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqWorkerConnectionProvider
    _connectionProvider;

    private readonly RabbitMqTopology
        _topology;

    private readonly IntegrationEventDeserializer
        _deserializer;

    private readonly IIntegrationEventDispatcher
        _dispatcher;

    private readonly IServiceScopeFactory
    _scopeFactory;

    private readonly RabbitMqMonitoringMetrics
    _monitoringMetrics;

    private readonly ILogger<
        IntegrationEventConsumer>
        _logger;

    private IConnection? _connection;

    private IChannel? _channel;

    private string? _consumerTag;

    private readonly RabbitMqConsumerOperations
    _consumerOperations;

    private int _activeMessageCount;
    private TaskCompletionSource
        _messagesDrained =
            CreateCompletedDrainSource();

    private bool _isStopping;

    private bool _disposed;

    public IntegrationEventConsumer(
        IOptions<RabbitMqOptions> options,
        RabbitMqWorkerConnectionProvider
            connectionProvider,
        RabbitMqTopology topology,
        IntegrationEventDeserializer deserializer,
        IIntegrationEventDispatcher dispatcher,
        IServiceScopeFactory scopeFactory,
        RabbitMqMonitoringMetrics monitoringMetrics,
        RabbitMqConsumerOperations
    consumerOperations,
        ILogger<IntegrationEventConsumer> logger)
    {
        _options =
            options.Value;

        _connectionProvider =
            connectionProvider;

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

        _monitoringMetrics =
    monitoringMetrics;

        _consumerOperations =
    consumerOperations;

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

            _consumerTag =
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
                _consumerTag);

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
            await _connectionProvider
                .CreateAsync(
                    nameof(
                        IntegrationEventConsumer),
                    $"{_options.ConsumerClientName}-integration",
                    cancellationToken);

        _channel =
            await _connection
                .CreateChannelAsync(
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
            "RabbitMQ consumer initialized. "
            + "Consumer: {Consumer}, "
            + "queue: {Queue}, "
            + "prefetch count: {PrefetchCount}.",
            nameof(
                IntegrationEventConsumer),
            _options.IntegrationEventQueue,
            _options.PrefetchCount);
    }

   



    private async Task HandleMessageAsync(
     object sender,
     BasicDeliverEventArgs eventArgs)
    {
        if (_isStopping)
        {
            _logger.LogInformation(
                "Integration event delivery {DeliveryTag} "
                + "was received while consumer is stopping "
                + "and will not start processing.",
                eventArgs.DeliveryTag);

            return;
        }

        BeginMessageProcessing();

        try
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
                RabbitMqMessageHelper
                    .GetRetryCount(
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

                    await _consumerOperations
                        .AcknowledgeAsync(
                            _channel!,
                            eventArgs.DeliveryTag,
                            nameof(
                                IntegrationEventConsumer));

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
                await _consumerOperations
                    .AcknowledgeAsync(
                        _channel!,
                        eventArgs.DeliveryTag,
                        nameof(
                            IntegrationEventConsumer));

                _monitoringMetrics
    .RecordSuccess();
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
        finally
        {
            EndMessageProcessing();
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
            await _consumerOperations
                .PublishForwardedAsync(
                    _channel!,
                    _options.RetryExchange,
                    retryRoutingKey,
                    eventArgs.BasicProperties,
                    eventArgs.Body,
                    nextRetryCount,
                    exception.Message,
                    _options
                        .IntegrationEventQueue,
                    nameof(
                        IntegrationEventConsumer));

            await _consumerOperations
                .AcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    nameof(
                        IntegrationEventConsumer));

            _monitoringMetrics
    .RecordRetry();

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
            await _consumerOperations
                .NegativeAcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    requeue:
                        true,
                    nameof(
                        IntegrationEventConsumer));
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
                RabbitMqMessageHelper
                    .CreateForwardProperties(
                        eventArgs.BasicProperties,
                        retryCount,
                        failureReason,
                        _options
                            .IntegrationEventQueue);

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

            await _consumerOperations
                .AcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    nameof(
                        IntegrationEventConsumer));

            _monitoringMetrics
    .RecordFailure();

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
RabbitMqMessageHelper
    .Truncate(
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

            await _consumerOperations
                .NegativeAcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    requeue:
                        true,
                    nameof(
                        IntegrationEventConsumer));
        }
    }
   
    private void BeginMessageProcessing()
    {
        if (Interlocked.Increment(
                ref _activeMessageCount) == 1)
        {
            _messagesDrained =
                new TaskCompletionSource(
                    TaskCreationOptions
                        .RunContinuationsAsynchronously);
        }
    }

    private void EndMessageProcessing()
    {
        if (Interlocked.Decrement(
                ref _activeMessageCount) == 0)
        {
            _messagesDrained
                .TrySetResult();
        }
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Graceful shutdown started for integration event consumer. "
            + "Active messages: {ActiveMessageCount}.",
            Volatile.Read(
                ref _activeMessageCount));

        _isStopping =
            true;

        if (_channel is { IsOpen: true } &&
            !string.IsNullOrWhiteSpace(
                _consumerTag))
        {
            try
            {
                await _channel
                    .BasicCancelAsync(
                        _consumerTag,
                        cancellationToken:
                            CancellationToken.None);

                _logger.LogInformation(
                    "Integration event RabbitMQ consumer {ConsumerTag} cancelled. "
                    + "No new deliveries will be accepted.",
                    _consumerTag);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    exception,
                    "Integration event RabbitMQ consumer could not be cancelled cleanly.");
            }
        }

        if (Volatile.Read(
                ref _activeMessageCount) > 0)
        {
            _logger.LogInformation(
                "Waiting for {ActiveMessageCount} active integration event message(s) to finish.",
                Volatile.Read(
                    ref _activeMessageCount));

            try
            {
                await _messagesDrained
                    .Task
                    .WaitAsync(
                        cancellationToken);

                _logger.LogInformation(
                    "All active integration event messages completed successfully.");
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                _logger.LogWarning(
                    "Graceful shutdown timeout reached while waiting for integration event processing to finish.");
            }
        }

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

    private static TaskCompletionSource
    CreateCompletedDrainSource()
    {
        var source =
            new TaskCompletionSource(
                TaskCreationOptions
                    .RunContinuationsAsynchronously);

        source.TrySetResult();

        return source;
    }


}