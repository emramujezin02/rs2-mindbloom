using System.Text;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Monitoring;
using MindBloom.Shared.Observability;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class IntegrationEventConsumer
    : BackgroundService,
      IAsyncDisposable
{
    private static readonly EventId
    ConsumerStartedEvent =
        new(
            4300,
            "IntegrationEventConsumerStarted");

    private static readonly EventId
        ConsumerStoppingEvent =
            new(
                4301,
                "IntegrationEventConsumerStopping");

    private static readonly EventId
        ConsumerInitializationFailedEvent =
            new(
                4302,
                "IntegrationEventConsumerInitializationFailed");

    private static readonly EventId
        ConsumerInitializedEvent =
            new(
                4303,
                "IntegrationEventConsumerInitialized");

    private static readonly EventId
        DeliveryIgnoredDuringShutdownEvent =
            new(
                4310,
                "IntegrationEventDeliveryIgnoredDuringShutdown");

    private static readonly EventId
        ChannelUnavailableEvent =
            new(
                4311,
                "IntegrationEventChannelUnavailable");

    private static readonly EventId
        DuplicateEventDetectedEvent =
            new(
                4312,
                "DuplicateIntegrationEventDetected");

    private static readonly EventId
        EventProcessingStartedEvent =
            new(
                4313,
                "IntegrationEventProcessingStarted");

    private static readonly EventId
        UnsupportedEventEvent =
            new(
                4320,
                "UnsupportedIntegrationEvent");

    private static readonly EventId
        InvalidJsonEvent =
            new(
                4321,
                "InvalidIntegrationEventJson");

    private static readonly EventId
        InvalidEventDataEvent =
            new(
                4322,
                "InvalidIntegrationEventData");

    private static readonly EventId
        RetryExhaustedEvent =
            new(
                4330,
                "IntegrationEventRetryExhausted");

    private static readonly EventId
        RetryScheduledEvent =
            new(
                4331,
                "IntegrationEventRetryScheduled");

    private static readonly EventId
        RetryPublishFailedEvent =
            new(
                4332,
                "IntegrationEventRetryPublishFailed");

    private static readonly EventId
        MovedToDeadLetterQueueEvent =
            new(
                4340,
                "IntegrationEventMovedToDeadLetterQueue");

    private static readonly EventId
        DeadLetterPublishFailedEvent =
            new(
                4341,
                "IntegrationEventDeadLetterPublishFailed");

    private static readonly EventId
        GracefulShutdownStartedEvent =
            new(
                4350,
                "IntegrationEventGracefulShutdownStarted");

    private static readonly EventId
        ConsumerCancelledEvent =
            new(
                4351,
                "IntegrationEventConsumerCancelled");

    private static readonly EventId
        ConsumerCancelFailedEvent =
            new(
                4352,
                "IntegrationEventConsumerCancelFailed");

    private static readonly EventId
        WaitingForMessagesEvent =
            new(
                4353,
                "IntegrationEventWaitingForMessages");

    private static readonly EventId
        MessagesDrainedEvent =
            new(
                4354,
                "IntegrationEventMessagesDrained");

    private static readonly EventId
        ShutdownTimeoutEvent =
            new(
                4355,
                "IntegrationEventShutdownTimeout");

    private static readonly EventId
        ConsumerStoppedEvent =
            new(
                4356,
                "IntegrationEventConsumerStopped");

    private static readonly EventId
        ChannelCloseFailedEvent =
            new(
                4360,
                "IntegrationEventChannelCloseFailed");

    private static readonly EventId
        ConnectionCloseFailedEvent =
            new(
                4361,
                "IntegrationEventConnectionCloseFailed");

    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqWorkerConnectionProvider
    _connectionProvider;

    private readonly RabbitMqTopology
        _topology;

    private readonly ApplicationMetrics
    _applicationMetrics;

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
        ApplicationMetrics applicationMetrics,
        RabbitMqConsumerOperations
    consumerOperations,
        ILogger<IntegrationEventConsumer> logger)
    {
        _options =
            options.Value;

        _applicationMetrics =
    applicationMetrics;

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
                ConsumerStartedEvent,
                "Integration event consumer started. Module: {Module}, Queue: {Queue}, ConsumerTag: {ConsumerTag}.",
                "IntegrationEventConsumer",
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
                ConsumerStoppingEvent,
                "Integration event consumer is stopping. Module: {Module}.",
                "IntegrationEventConsumer");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                ConsumerInitializationFailedEvent,
                "Integration event consumer could not be started. Module: {Module}, FailureType: {FailureType}.",
                "IntegrationEventConsumer",
                exception.GetType().Name);

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
            ConsumerInitializedEvent,
            "RabbitMQ integration event consumer initialized. Module: {Module}, Consumer: {Consumer}, Queue: {Queue}, PrefetchCount: {PrefetchCount}.",
            "IntegrationEventConsumer",
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
                DeliveryIgnoredDuringShutdownEvent,
                "Integration event delivery received while consumer is stopping and will not start processing. Module: {Module}, DeliveryTag: {DeliveryTag}.",
                "IntegrationEventConsumer",
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
                    ChannelUnavailableEvent,
                    "RabbitMQ channel is unavailable for integration event delivery. Module: {Module}, DeliveryTag: {DeliveryTag}.",
                    "IntegrationEventConsumer",
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

                using var messageLogScope =
    _logger.BeginScope(
        new Dictionary<string, object?>
        {
            ["CorrelationId"] =
                integrationEvent
                    .CorrelationId,

            ["IntegrationEventId"] =
                integrationEvent
                    .EventId,

            ["EventType"] =
                integrationEvent
                    .GetType()
                    .Name,

            ["RoutingKey"] =
                eventArgs.RoutingKey,

            ["Module"] =
                "IntegrationEventConsumer"
        });

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
                        DuplicateEventDetectedEvent,
                        "Duplicate integration event detected and will be acknowledged without processing.");

                    await _consumerOperations
                        .AcknowledgeAsync(
                            _channel!,
                            eventArgs.DeliveryTag,
                            nameof(
                                IntegrationEventConsumer));

                    return;
                }

                _logger.LogInformation(
                    EventProcessingStartedEvent,
                    "Processing integration event. Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    retryCount + 1,
                    _options.MaximumRetryCount + 1);

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

                _applicationMetrics
    .RecordRabbitMqConsumed();
            }
            catch (NotSupportedException exception)
            {
                _logger.LogError(
                    UnsupportedEventEvent,
                    exception,
                    "Unsupported integration event will be moved to DLQ. Module: {Module}, RoutingKey: {RoutingKey}.",
                    "IntegrationEventConsumer",
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
                    InvalidJsonEvent,
                    exception,
                    "Invalid integration event JSON will be moved to DLQ. Module: {Module}, RoutingKey: {RoutingKey}.",
                    "IntegrationEventConsumer",
                    eventArgs.RoutingKey);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message);
            }
            catch (ArgumentException exception)
            {
                _logger.LogError(
                    InvalidEventDataEvent,
                    "Invalid integration event data will be moved to DLQ. Module: {Module}, RoutingKey: {RoutingKey}, FailureType: {FailureType}.",
                    "IntegrationEventConsumer",
                    eventArgs.RoutingKey,
                    exception.GetType().Name);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message);
            }
            catch (Exception exception)
            {
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
                RetryExhaustedEvent,
                "Integration event exhausted all delivery attempts and will be moved to DLQ. Module: {Module}, RoutingKey: {RoutingKey}, MaximumAttempts: {MaximumAttempts}, FailureType: {FailureType}.",
                "IntegrationEventConsumer",
                eventArgs.RoutingKey,
                _options.MaximumRetryCount + 1,
                exception.GetType().Name);

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

            _applicationMetrics.RecordRetry(
    "integration-event-consumer");

            _logger.LogWarning(
                RetryScheduledEvent,
                "Integration event scheduled for retry. Module: {Module}, RoutingKey: {RoutingKey}, RetryCount: {RetryCount}, MaximumRetryCount: {MaximumRetryCount}, DelayMilliseconds: {DelayMilliseconds}, FailureType: {FailureType}.",
                "IntegrationEventConsumer",
                eventArgs.RoutingKey,
                nextRetryCount,
                _options.MaximumRetryCount,
                delayMilliseconds,
                exception.GetType().Name);
        }
        catch (Exception publishException)
        {
            _logger.LogCritical(
                RetryPublishFailedEvent,
                publishException,
                "Integration event could not be published to retry exchange. Original delivery will be requeued. Module: {Module}, RoutingKey: {RoutingKey}.",
                "IntegrationEventConsumer",
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

            _applicationMetrics
    .RecordDlqMoved();

            _logger.LogError(
     MovedToDeadLetterQueueEvent,
     "Integration event moved to DLQ. Module: {Module}, RoutingKey: {RoutingKey}, MessageId: {MessageId}, CorrelationId: {CorrelationId}, Queue: {DeadLetterQueue}, RetryCount: {RetryCount}.",
     "IntegrationEventConsumer",
     eventArgs.RoutingKey,
     eventArgs.BasicProperties
         .MessageId,
     eventArgs.BasicProperties
         .CorrelationId,
     _options
         .IntegrationEventDeadLetterQueue,
     retryCount);

        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                DeadLetterPublishFailedEvent,
                exception,
                "Integration event could not be moved to DLQ. Original message will be requeued. Module: {Module}, RoutingKey: {RoutingKey}.",
                "IntegrationEventConsumer",
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
            GracefulShutdownStartedEvent,
            "Graceful shutdown started for integration event consumer. Module: {Module}, ActiveMessageCount: {ActiveMessageCount}.",
            "IntegrationEventConsumer",
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
                    ConsumerCancelledEvent,
                    "Integration event RabbitMQ consumer cancelled. Module: {Module}, ConsumerTag: {ConsumerTag}. No new deliveries will be accepted.",
                    "IntegrationEventConsumer",
                    _consumerTag);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
    ConsumerCancelFailedEvent,
    exception,
    "Integration event RabbitMQ consumer could not be cancelled cleanly. Module: {Module}.",
    "IntegrationEventConsumer");
            }
        }

        if (Volatile.Read(
                ref _activeMessageCount) > 0)
        {
            _logger.LogInformation(
                WaitingForMessagesEvent,
                "Waiting for active integration event messages to finish. Module: {Module}, ActiveMessageCount: {ActiveMessageCount}.",
                "IntegrationEventConsumer",
                Volatile.Read(
                    ref _activeMessageCount));

            try
            {
                await _messagesDrained
                    .Task
                    .WaitAsync(
                        cancellationToken);

                _logger.LogInformation(
    MessagesDrainedEvent,
    "All active integration event messages completed successfully. Module: {Module}.",
    "IntegrationEventConsumer");
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                _logger.LogWarning(
    ShutdownTimeoutEvent,
    "Graceful shutdown timeout reached while waiting for integration event processing to finish. Module: {Module}.",
    "IntegrationEventConsumer");
            }
        }

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();

        _logger.LogInformation(
            ConsumerStoppedEvent,
            "Integration event consumer stopped successfully. Module: {Module}.",
            "IntegrationEventConsumer");
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
                    ChannelCloseFailedEvent,
                    exception,
                    "Integration event RabbitMQ channel could not be closed cleanly. Module: {Module}.",
                    "IntegrationEventConsumer");
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
                    ConnectionCloseFailedEvent,
                    exception,
                    "Integration event RabbitMQ connection could not be closed cleanly. Module: {Module}.",
                    "IntegrationEventConsumer");
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