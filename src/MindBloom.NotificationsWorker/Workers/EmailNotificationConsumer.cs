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
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Monitoring;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class EmailNotificationConsumer :
    BackgroundService,
    IAsyncDisposable
{
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
        EmailMessageBodyBuilder bodyBuilder,
        IServiceScopeFactory scopeFactory,
        RabbitMqMonitoringMetrics monitoringMetrics,
        ILogger<EmailNotificationConsumer> logger)
    {
        _options =
            options.Value;

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
                "Notifications worker started consuming queue {Queue}. Consumer tag: {ConsumerTag}. Maximum retries: {MaximumRetryCount}.",
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
                "Notifications worker is stopping.");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "Notifications worker stopped because consumer initialization failed.");

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
            "RabbitMQ consumer initialized. "
            + "Consumer: {Consumer}, "
            + "queue: {Queue}, "
            + "prefetch count: {PrefetchCount}.",
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
                "Email notification delivery {DeliveryTag} "
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
                    "RabbitMQ channel is unavailable for delivery {DeliveryTag}.",
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
                        "Duplicate email notification detected. "
                        + "Message ID: {MessageId}, "
                        + "event type: {EventType}, "
                        + "correlation ID: {CorrelationId}. "
                        + "Message will be acknowledged without sending the email again.",
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
                    "Processing email notification {MessageId}. "
                    + "Attempt {CurrentAttempt}/{MaximumAttempts}. "
                    + "Correlation ID: {CorrelationId}.",
                    message.MessageId,
                    currentAttempt,
                    maximumAttempts,
                    message.CorrelationId);

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

                _logger.LogInformation(
                    "Email notification {MessageId} sent successfully, "
                    + "marked as processed and acknowledged. "
                    + "Attempt: {Attempt}, correlation ID: {CorrelationId}.",
                    message.MessageId,
                    currentAttempt,
                    message.CorrelationId);
            }
            catch (JsonException exception)
            {
                _logger.LogError(
                    exception,
                    "Delivery {DeliveryTag} contains invalid JSON and will be moved directly to the dead-letter queue.",
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
                    exception,
                    "Email notification {MessageId} contains invalid data and will be moved directly to the dead-letter queue.",
                    message?.MessageId);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message,
                    message?.MessageId);
            }
            catch (InvalidOperationException exception)
            {
                _logger.LogError(
                    exception,
                    "Email notification {MessageId} cannot be processed and will be moved directly to the dead-letter queue.",
                    message?.MessageId);

                await MoveToDeadLetterQueueAsync(
                    eventArgs,
                    retryCount,
                    exception.Message,
                    message?.MessageId);
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Sending email notification {MessageId} failed on attempt {Attempt}.",
                    message?.MessageId,
                    retryCount + 1);

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
                "Email notification {MessageId} exhausted all {MaximumAttempts} attempts and will be moved to DLQ.",
                messageId,
                _options.MaximumRetryCount + 1);

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

            _logger.LogWarning(
                "Email notification {MessageId} scheduled for retry {RetryCount}/{MaximumRetryCount} after {DelayMilliseconds} ms.",
                messageId,
                nextRetryCount,
                _options.MaximumRetryCount,
                delayMilliseconds);
        }
        catch (Exception publishException)
        {
            _logger.LogCritical(
                publishException,
                "Email notification {MessageId} could not be published to retry exchange. Original delivery will be requeued.",
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

            _logger.LogError(
                "Email notification moved to DLQ. "
                + "MessageId: {MessageId}, "
                + "CorrelationId: {CorrelationId}, "
                + "Queue: {DeadLetterQueue}, "
                + "RetryCount: {RetryCount}, "
                + "FailureReason: {FailureReason}.",
                messageId,
                eventArgs.BasicProperties
                    .CorrelationId,
                _options.DeadLetterQueue,
                retryCount,
                RabbitMqMessageHelper.Truncate(
                    failureReason,
                    500));
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "Email notification {MessageId} could not be moved to DLQ. Original delivery will be requeued.",
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
            "Graceful shutdown started for email notification consumer. "
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
                    "Email notification RabbitMQ consumer {ConsumerTag} cancelled. "
                    + "No new deliveries will be accepted.",
                    _consumerTag);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    exception,
                    "Email notification RabbitMQ consumer could not be cancelled cleanly.");
            }
        }

        if (Volatile.Read(
                ref _activeMessageCount) > 0)
        {
            _logger.LogInformation(
                "Waiting for {ActiveMessageCount} active email notification message(s) to finish.",
                Volatile.Read(
                    ref _activeMessageCount));

            try
            {
                await _messagesDrained
                    .Task
                    .WaitAsync(
                        cancellationToken);

                _logger.LogInformation(
                    "All active email notification messages completed successfully.");
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                _logger.LogWarning(
                    "Graceful shutdown timeout reached while waiting for email notification processing to finish.");
            }
        }

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();

        _logger.LogInformation(
            "Email notification consumer stopped successfully.");
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
                    "RabbitMQ channel could not be closed cleanly.");
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
                    exception,
                    "RabbitMQ connection could not be closed cleanly.");
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