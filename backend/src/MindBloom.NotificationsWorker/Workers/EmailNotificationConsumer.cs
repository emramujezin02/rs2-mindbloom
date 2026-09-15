using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.NotificationsWorker.Messaging;
using MindBloom.NotificationsWorker.Services;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.NotificationsWorker.Monitoring;
using MindBloom.Shared.Observability;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class EmailNotificationConsumer :
    BackgroundService,
    IAsyncDisposable
{
    private static readonly EventId
    ConsumerStartedEvent =
        new(
            4000,
            "EmailConsumerStarted");

    private static readonly EventId
        ConsumerStoppingEvent =
            new(
                4001,
                "EmailConsumerStopping");

    private static readonly EventId
        ConsumerInitializationFailedEvent =
            new(
                4002,
                "EmailConsumerInitializationFailed");

    private static readonly EventId
        ConsumerInitializedEvent =
            new(
                4003,
                "EmailConsumerInitialized");

    private static readonly EventId
        DeliveryIgnoredDuringShutdownEvent =
            new(
                4010,
                "EmailDeliveryIgnoredDuringShutdown");

    private static readonly EventId
        ChannelUnavailableEvent =
            new(
                4011,
                "EmailConsumerChannelUnavailable");

    private static readonly EventId
        DuplicateMessageEvent =
            new(
                4012,
                "DuplicateEmailMessage");

    private static readonly EventId
        MessageProcessingStartedEvent =
            new(
                4013,
                "EmailMessageProcessingStarted");

    private static readonly EventId
        MessageProcessedEvent =
            new(
                4014,
                "EmailMessageProcessed");

    private static readonly EventId
        InvalidJsonEvent =
            new(
                4020,
                "EmailMessageInvalidJson");

    private static readonly EventId
        InvalidMessageEvent =
            new(
                4021,
                "EmailMessageInvalid");

    private static readonly EventId
        MessageCannotBeProcessedEvent =
            new(
                4022,
                "EmailMessageCannotBeProcessed");

    private static readonly EventId
        RetryExhaustedEvent =
            new(
                4030,
                "EmailRetryExhausted");

    private static readonly EventId
        RetryScheduledEvent =
            new(
                4031,
                "EmailRetryScheduled");

    private static readonly EventId
        RetryPublishFailedEvent =
            new(
                4032,
                "EmailRetryPublishFailed");

    private static readonly EventId
        MovedToDeadLetterQueueEvent =
            new(
                4040,
                "EmailMovedToDeadLetterQueue");

    private static readonly EventId
        DeadLetterPublishFailedEvent =
            new(
                4041,
                "EmailDeadLetterPublishFailed");

    private static readonly EventId
        GracefulShutdownStartedEvent =
            new(
                4050,
                "EmailConsumerGracefulShutdownStarted");

    private static readonly EventId
        ConsumerCancelledEvent =
            new(
                4051,
                "EmailConsumerCancelled");

    private static readonly EventId
        ConsumerCancelFailedEvent =
            new(
                4052,
                "EmailConsumerCancelFailed");

    private static readonly EventId
        WaitingForMessagesEvent =
            new(
                4053,
                "EmailConsumerWaitingForMessages");

    private static readonly EventId
        MessagesDrainedEvent =
            new(
                4054,
                "EmailConsumerMessagesDrained");

    private static readonly EventId
        ShutdownTimeoutEvent =
            new(
                4055,
                "EmailConsumerShutdownTimeout");

    private static readonly EventId
        ConsumerStoppedEvent =
            new(
                4056,
                "EmailConsumerStopped");

    private static readonly EventId
        ChannelCloseFailedEvent =
            new(
                4060,
                "EmailConsumerChannelCloseFailed");

    private static readonly EventId
        ConnectionCloseFailedEvent =
            new(
                4061,
                "EmailConsumerConnectionCloseFailed");

    private static readonly JsonSerializerOptions
        JsonOptions =
            new(JsonSerializerDefaults.Web)
            {
                PropertyNameCaseInsensitive =
                    true
            };

    private readonly RabbitMqOptions
        _options;

    private readonly IServiceScopeFactory
    _scopeFactory;

    private readonly RabbitMqMonitoringMetrics
    _monitoringMetrics;

    private readonly ApplicationMetrics
    _applicationMetrics;

    private readonly RabbitMqWorkerConnectionProvider
        _connectionProvider;

    private readonly RabbitMqTopology
        _topology;

    private readonly IEmailService
        _emailService;

    private readonly EmailMessageBodyBuilder
        _bodyBuilder;

    private readonly RabbitMqConsumerOperations
    _consumerOperations;

    private readonly ILogger<EmailNotificationConsumer>
        _logger;

    private IConnection? _connection;

    private IChannel? _channel;

    private string? _consumerTag;

    private int _activeMessageCount;

    private TaskCompletionSource _messagesDrained = CreateCompletedDrainSource();

    private bool _isStopping;

    private bool _disposed;

    public EmailNotificationConsumer(
        IOptions<RabbitMqOptions> options,
        RabbitMqWorkerConnectionProvider
            connectionProvider,
        RabbitMqTopology topology,
        IEmailService emailService,
        RabbitMqConsumerOperations
    consumerOperations,
        ApplicationMetrics applicationMetrics,
        EmailMessageBodyBuilder bodyBuilder,
        IServiceScopeFactory scopeFactory,
        RabbitMqMonitoringMetrics monitoringMetrics,
        ILogger<EmailNotificationConsumer> logger)
    {
        _options =
            options.Value;

        _applicationMetrics =
    applicationMetrics;

        _connectionProvider =
            connectionProvider;

        _topology =
            topology;

        _consumerOperations =
    consumerOperations;

        _scopeFactory =
    scopeFactory;

        _emailService =
            emailService;

        _bodyBuilder =
            bodyBuilder;

        _logger =
            logger;

        _monitoringMetrics =
    monitoringMetrics;
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
                            _options.EmailQueue,
                        autoAck:
                            false,
                        consumer:
                            consumer,
                        cancellationToken:
                            stoppingToken);

            _logger.LogInformation(
                ConsumerStartedEvent,
                "Notifications worker started consuming email queue. Module: {Module}, Queue: {Queue}, ConsumerTag: {ConsumerTag}, MaximumRetryCount: {MaximumRetryCount}.",
                "EmailConsumer",
                _options.EmailQueue,
                _consumerTag,
                _options.MaximumRetryCount);

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
                "Notifications worker email consumer is stopping. Module: {Module}.",
                "EmailConsumer");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                ConsumerInitializationFailedEvent,
                "Notifications worker stopped because email consumer initialization failed. Module: {Module}, FailureType: {FailureType}.",
                "EmailConsumer",
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
                        EmailNotificationConsumer),
                    $"{_options.ConsumerClientName}-email",
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
            "RabbitMQ email consumer initialized. Module: {Module}, Consumer: {Consumer}, Queue: {Queue}, PrefetchCount: {PrefetchCount}.",
            "EmailConsumer",
            nameof(
                EmailNotificationConsumer),
            _options.EmailQueue,
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
                "Email notification delivery received while consumer is stopping and will not start processing. Module: {Module}, DeliveryTag: {DeliveryTag}.",
                "EmailConsumer",
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
                    "RabbitMQ channel is unavailable for email delivery. Module: {Module}, DeliveryTag: {DeliveryTag}.",
                    "EmailConsumer",
                    eventArgs.DeliveryTag);

                return;
            }

            EmailNotificationMessage? message =
                null;

            var retryCount =
                RabbitMqMessageHelper
                    .GetRetryCount(
                        eventArgs
                            .BasicProperties
                            .Headers);

            try
            {
                message =
                    JsonSerializer
                        .Deserialize<
                            EmailNotificationMessage>(
                            eventArgs.Body.Span,
                            JsonOptions);

                if (message is null)
                {
                    throw new JsonException(
                        "Email notification message could not be deserialized.");
                }

                ValidateMessage(
                    message);

                using var messageLogScope =
    _logger.BeginScope(
        new Dictionary<string, object?>
        {
            ["CorrelationId"] =
                message.CorrelationId,

            ["MessageId"] =
                message.MessageId,

            ["EventType"] =
                message.EventType.ToString(),

            ["Module"] =
                "EmailConsumer"
        });


                var consumerName =
                    nameof(
                        EmailNotificationConsumer);

                using var scope =
                    _scopeFactory
                        .CreateScope();

                var processedMessageService =
                    scope.ServiceProvider
                        .GetRequiredService<
                            ProcessedMessageService>();

                var alreadyProcessed =
                    await processedMessageService
                        .IsProcessedAsync(
                            message.MessageId,
                            consumerName,
                            CancellationToken.None);

                if (alreadyProcessed)
                {
                    _logger.LogWarning(
                        DuplicateMessageEvent,
                        "Duplicate email notification detected and will be acknowledged without sending again. MessageId: {MessageId}, EventType: {EventType}, CorrelationId: {CorrelationId}.",
                        message.MessageId,
                        message.EventType,
                        message.CorrelationId);

                    await _consumerOperations
                        .AcknowledgeAsync(
                            _channel!,
                            eventArgs.DeliveryTag,
                            nameof(
                                EmailNotificationConsumer));

                    return;
                }

                var currentAttempt =
                    retryCount + 1;

                var maximumAttempts =
                    _options
                        .MaximumRetryCount + 1;

                _logger.LogInformation(
                    MessageProcessingStartedEvent,
                    "Processing email notification. CurrentAttempt: {CurrentAttempt}, MaximumAttempts: {MaximumAttempts}.",
                    currentAttempt,
                    maximumAttempts);

                var emailBody =
                    _bodyBuilder.Build(
                        message);

                await _emailService
                    .SendAsync(
                        message.RecipientEmail,
                        message.Subject,
                        emailBody);

                await processedMessageService
                    .MarkAsProcessedAsync(
                        message.MessageId,
                        consumerName,
                        nameof(
                            EmailNotificationMessage),
                        message.CorrelationId,
                        CancellationToken.None);

                await _consumerOperations
                    .AcknowledgeAsync(
                        _channel!,
                        eventArgs.DeliveryTag,
                        nameof(
                            EmailNotificationConsumer));

                _monitoringMetrics
    .RecordSuccess();

                _applicationMetrics
    .RecordRabbitMqConsumed();

                _logger.LogInformation(
                    MessageProcessedEvent,
                    "Email notification sent successfully, marked as processed and acknowledged. Attempt: {Attempt}.",
                    currentAttempt);
            }
            catch (JsonException exception)
            {
                _logger.LogError(
                    InvalidJsonEvent,
                    exception,
                    "Email delivery contains invalid JSON and will be moved directly to the dead-letter queue. Module: {Module}, DeliveryTag: {DeliveryTag}.",
                    "EmailConsumer",
                    eventArgs.DeliveryTag);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message,
                    message?.MessageId);
            }
            catch (ArgumentException exception)
            {
                _logger.LogError(
                    InvalidMessageEvent,
                    "Email notification contains invalid data and will be moved directly to the dead-letter queue. Module: {Module}, MessageId: {MessageId}, FailureType: {FailureType}.",
                    "EmailConsumer",
                    message?.MessageId,
                    exception.GetType().Name);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message,
                    message?.MessageId);
            }
            catch (InvalidOperationException exception)
            {
                _logger.LogError(
                    MessageCannotBeProcessedEvent,
                    "Email notification cannot be processed and will be moved directly to the dead-letter queue. Module: {Module}, MessageId: {MessageId}, FailureType: {FailureType}.",
                    "EmailConsumer",
                    message?.MessageId,
                    exception.GetType().Name);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message,
                    message?.MessageId);
            }
            catch (Exception exception)
            {
                await HandleTransientFailureAsync(
                    eventArgs,
                    retryCount,
                    exception,
                    message?.MessageId);
            }
        }
        finally
        {
            EndMessageProcessing();
        }
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
        var remaining =
            Interlocked.Decrement(
                ref _activeMessageCount);

        if (remaining == 0)
        {
            _messagesDrained
                .TrySetResult();
        }
    }

    private async Task HandleTransientFailureAsync(
        BasicDeliverEventArgs eventArgs,
        int retryCount,
        Exception exception,
        Guid? messageId)
    {
        if (retryCount >=
            _options.MaximumRetryCount)
        {
            _logger.LogError(
                RetryExhaustedEvent,
                "Email notification exhausted all delivery attempts and will be moved to DLQ. Module: {Module}, MessageId: {MessageId}, MaximumAttempts: {MaximumAttempts}, FailureType: {FailureType}.",
                "EmailConsumer",
                messageId,
                _options.MaximumRetryCount + 1,
                exception.GetType().Name);

            await MoveToDeadLetterQueueAsync(
                eventArgs,
                retryCount,
                exception.Message,
                messageId);

            return;
        }

        var delayMilliseconds =
            _topology
                .RetryDelays[
                    retryCount];

        var nextRetryCount =
            retryCount + 1;

        var retryRoutingKey =
            _topology
                .GetRetryRoutingKey(
                    delayMilliseconds);

        try
        {
            var properties =
                RabbitMqMessageHelper
                    .CreateForwardProperties(
                        eventArgs.BasicProperties,
                        nextRetryCount,
                        exception.Message,
                        _options.EmailQueue);

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

            await _consumerOperations
                .AcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    nameof(
                        EmailNotificationConsumer));

            _monitoringMetrics
    .RecordRetry();

            _applicationMetrics.RecordRetry(
    "email-consumer");

            _logger.LogWarning(
                RetryScheduledEvent,
                "Email notification scheduled for retry. Module: {Module}, MessageId: {MessageId}, RetryCount: {RetryCount}, MaximumRetryCount: {MaximumRetryCount}, DelayMilliseconds: {DelayMilliseconds}, FailureType: {FailureType}.",
                "EmailConsumer",
                messageId,
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
                "Email notification could not be published to retry exchange. Original delivery will be requeued. Module: {Module}, MessageId: {MessageId}.",
                "EmailConsumer",
                messageId);

            await _consumerOperations
                .NegativeAcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    requeue:
                        true,
                    nameof(
                        EmailNotificationConsumer));
        }
    }

    private async Task MoveToDeadLetterQueueAsync(
        BasicDeliverEventArgs eventArgs,
        int retryCount,
        string failureReason,
        Guid? messageId)
    {
        try
        {
            var properties =
                RabbitMqMessageHelper
                    .CreateForwardProperties(
                        eventArgs.BasicProperties,
                        retryCount,
                        failureReason,
                        _options.EmailQueue);

            await _channel!
                .BasicPublishAsync(
                    exchange:
                        _options
                            .DeadLetterExchange,
                    routingKey:
                        _options
                            .DeadLetterRoutingKey,
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
                        EmailNotificationConsumer));

            _monitoringMetrics
    .RecordFailure();

            _applicationMetrics
    .RecordDlqMoved();

            _logger.LogError(
                MovedToDeadLetterQueueEvent,
                "Email notification moved to DLQ. Module: {Module}, MessageId: {MessageId}, CorrelationId: {CorrelationId}, Queue: {DeadLetterQueue}, RetryCount: {RetryCount}.",
                "EmailConsumer",
                messageId,
                eventArgs.BasicProperties
                    .CorrelationId,
                _options.DeadLetterQueue,
                retryCount);
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                DeadLetterPublishFailedEvent,
                exception,
                "Email notification could not be moved to DLQ. Original delivery will be requeued. Module: {Module}, MessageId: {MessageId}.",
                "EmailConsumer",
                messageId);

            await _consumerOperations
                .NegativeAcknowledgeAsync(
                    _channel!,
                    eventArgs.DeliveryTag,
                    requeue:
                        true,
                    nameof(
                        EmailNotificationConsumer));
        }
    }

    private static void ValidateMessage(
        EmailNotificationMessage message)
    {
        if (message.MessageId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "Email notification MessageId cannot be empty.");
        }

        if (message.CorrelationId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "Email notification CorrelationId cannot be empty.");
        }

        if (message.EventType ==
            NotificationEventType.Unknown)
        {
            throw new ArgumentException(
                "Email notification EventType cannot be Unknown.");
        }

        if (string.IsNullOrWhiteSpace(
                message.RecipientEmail))
        {
            throw new ArgumentException(
                "Email notification recipient is required.");
        }

        if (string.IsNullOrWhiteSpace(
                message.Subject))
        {
            throw new ArgumentException(
                "Email notification subject is required.");
        }

        var hasBody =
            !string.IsNullOrWhiteSpace(
                message.Body);

        var hasTemplate =
            !string.IsNullOrWhiteSpace(
                message.TemplateName);

        if (!hasBody &&
            !hasTemplate)
        {
            throw new ArgumentException(
                "Email notification must contain either Body or TemplateName.");
        }
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            GracefulShutdownStartedEvent,
            "Graceful shutdown started for email notification consumer. Module: {Module}, ActiveMessageCount: {ActiveMessageCount}.",
            "EmailConsumer",
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
                    "Email notification RabbitMQ consumer cancelled. Module: {Module}, ConsumerTag: {ConsumerTag}. No new deliveries will be accepted.",
                    "EmailConsumer",
                    _consumerTag);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
   ConsumerCancelFailedEvent,
   exception,
   "Email notification RabbitMQ consumer could not be cancelled cleanly. Module: {Module}.",
   "EmailConsumer");
            }
        }

        if (Volatile.Read(
                ref _activeMessageCount) > 0)
        {
            _logger.LogInformation(
                WaitingForMessagesEvent,
                "Waiting for active email notification messages to finish. Module: {Module}, ActiveMessageCount: {ActiveMessageCount}.",
                "EmailConsumer",
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
    "All active email notification messages completed successfully. Module: {Module}.",
    "EmailConsumer");
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                _logger.LogWarning(
    ShutdownTimeoutEvent,
    "Graceful shutdown timeout reached while waiting for email notification processing to finish. Module: {Module}.",
    "EmailConsumer");
            }
        }

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();

        _logger.LogInformation(
    ConsumerStoppedEvent,
    "Email notification consumer stopped successfully. Module: {Module}.",
    "EmailConsumer");
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
                    "RabbitMQ email consumer channel could not be closed cleanly. Module: {Module}.",
                    "EmailConsumer");
            }

            await _channel.DisposeAsync();

            _channel = null;
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
                    "RabbitMQ email consumer connection could not be closed cleanly. Module: {Module}.",
                    "EmailConsumer");
            }

            await _connection.DisposeAsync();

            _connection = null;
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