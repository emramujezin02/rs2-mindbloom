using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.NotificationsWorker.Configuration;
using MindBloom.NotificationsWorker.Messaging;
using MindBloom.NotificationsWorker.Services;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class EmailNotificationConsumer :
    BackgroundService,
    IAsyncDisposable
{
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web)
        {
            PropertyNameCaseInsensitive = true
        };

    private readonly RabbitMqConsumerOptions _options;
    private readonly IEmailService _emailService;
    private readonly EmailMessageBodyBuilder _bodyBuilder;
    private readonly ILogger<EmailNotificationConsumer> _logger;

    private IConnection? _connection;
    private IChannel? _channel;
    private RabbitMqTopology? _topology;
    private bool _disposed;

    public EmailNotificationConsumer(
        IOptions<RabbitMqConsumerOptions> options,
        IEmailService emailService,
        EmailMessageBodyBuilder bodyBuilder,
        ILogger<EmailNotificationConsumer> logger,
        ILogger<RabbitMqTopology> topologyLogger)
    {
        _options = options.Value;
        _emailService = emailService;
        _bodyBuilder = bodyBuilder;
        _logger = logger;

        _topology = new RabbitMqTopology(
            _options,
            topologyLogger);
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        try
        {
            await InitializeRabbitMqAsync(stoppingToken);

            var consumer =
                new AsyncEventingBasicConsumer(_channel!);

            consumer.ReceivedAsync += HandleMessageAsync;

            var consumerTag =
                await _channel!.BasicConsumeAsync(
                    queue: _options.EmailQueue,
                    autoAck: false,
                    consumer: consumer,
                    cancellationToken: stoppingToken);

            _logger.LogInformation(
                "Notifications worker started consuming queue {Queue}. Consumer tag: {ConsumerTag}. Maximum retries: {MaximumRetryCount}.",
                _options.EmailQueue,
                consumerTag,
                _options.MaximumRetryCount);

            await Task.Delay(
                Timeout.InfiniteTimeSpan,
                stoppingToken);
        }
        catch (OperationCanceledException)
            when (stoppingToken.IsCancellationRequested)
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
        var factory = new ConnectionFactory
        {
            HostName = _options.HostName,
            Port = _options.Port,
            UserName = _options.UserName,
            Password = _options.Password,
            VirtualHost = _options.VirtualHost,

            ClientProvidedName =
                _options.ClientProvidedName,

            AutomaticRecoveryEnabled =
                _options.AutomaticRecoveryEnabled,

            TopologyRecoveryEnabled = true,

            NetworkRecoveryInterval =
                TimeSpan.FromSeconds(
                    _options.NetworkRecoveryIntervalSeconds),

            RequestedHeartbeat =
                TimeSpan.FromSeconds(
                    _options.RequestedHeartbeatSeconds),

            ConsumerDispatchConcurrency = 1
        };

        _logger.LogInformation(
            "Connecting notifications worker to RabbitMQ at {HostName}:{Port}.",
            _options.HostName,
            _options.Port);

        _connection =
            await factory.CreateConnectionAsync(
                _options.ClientProvidedName,
                cancellationToken);

        _connection.ConnectionShutdownAsync +=
            OnConnectionShutdownAsync;

        _connection.ConnectionRecoveryErrorAsync +=
            OnConnectionRecoveryErrorAsync;

        _connection.RecoverySucceededAsync +=
            OnRecoverySucceededAsync;

        _channel =
            await _connection.CreateChannelAsync(
                cancellationToken: cancellationToken);

        await _topology!.DeclareAsync(
            _channel,
            cancellationToken);

        await _channel.BasicQosAsync(
            prefetchSize: 0,
            prefetchCount: _options.PrefetchCount,
            global: false,
            cancellationToken: cancellationToken);

        _logger.LogInformation(
            "Notifications worker connected to RabbitMQ successfully.");
    }

    private async Task HandleMessageAsync(
        object sender,
        BasicDeliverEventArgs eventArgs)
    {
        if (_channel is null || !_channel.IsOpen)
        {
            _logger.LogError(
                "RabbitMQ channel is unavailable for delivery {DeliveryTag}.",
                eventArgs.DeliveryTag);

            return;
        }

        EmailNotificationMessage? message = null;

        var retryCount =
            GetRetryCount(eventArgs.BasicProperties.Headers);

        try
        {
            message =
                JsonSerializer.Deserialize<EmailNotificationMessage>(
                    eventArgs.Body.Span,
                    JsonOptions);

            if (message is null)
            {
                throw new JsonException(
                    "Email notification message could not be deserialized.");
            }

            ValidateMessage(message);

            var currentAttempt = retryCount + 1;
            var maximumAttempts =
                _options.MaximumRetryCount + 1;

            _logger.LogInformation(
                "Processing email notification {MessageId}. Attempt {CurrentAttempt}/{MaximumAttempts}. Correlation ID: {CorrelationId}.",
                message.MessageId,
                currentAttempt,
                maximumAttempts,
                message.CorrelationId);

            var emailBody =
                _bodyBuilder.Build(message);

            await _emailService.SendAsync(
                message.RecipientEmail,
                message.Subject,
                emailBody);

            await AcknowledgeAsync(
                eventArgs.DeliveryTag);

            _logger.LogInformation(
                "Email notification {MessageId} sent successfully on attempt {Attempt} and acknowledged.",
                message.MessageId,
                currentAttempt);
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

    private async Task HandleTransientFailureAsync(
        BasicDeliverEventArgs eventArgs,
        int retryCount,
        Exception exception,
        Guid? messageId)
    {
        if (retryCount >= _options.MaximumRetryCount)
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
            _topology!.RetryDelays[retryCount];

        var nextRetryCount =
            retryCount + 1;

        var retryRoutingKey =
            _topology.GetRetryRoutingKey(
                delayMilliseconds);

        try
        {
            var properties =
                CreateForwardProperties(
                    eventArgs.BasicProperties,
                    nextRetryCount,
                    exception.Message);

            await _channel!.BasicPublishAsync(
                exchange: _options.RetryExchange,
                routingKey: retryRoutingKey,
                mandatory: true,
                basicProperties: properties,
                body: eventArgs.Body,
                cancellationToken: CancellationToken.None);

            /*
             * Originalna poruka dobija ACK tek nakon što je kopija
             * uspješno objavljena u odgovarajući retry queue.
             */
            await AcknowledgeAsync(
                eventArgs.DeliveryTag);

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

            /*
             * Nismo uspjeli sigurno proslijediti poruku u retry queue.
             * Zato originalnu poruku vraćamo u glavni queue.
             */
            await NegativeAcknowledgeAsync(
                eventArgs.DeliveryTag,
                requeue: true);
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
                CreateForwardProperties(
                    eventArgs.BasicProperties,
                    retryCount,
                    failureReason);

            await _channel!.BasicPublishAsync(
                exchange: _options.DeadLetterExchange,
                routingKey: _options.DeadLetterRoutingKey,
                mandatory: true,
                basicProperties: properties,
                body: eventArgs.Body,
                cancellationToken: CancellationToken.None);

            /*
             * ACK originala šaljemo tek kada je poruka objavljena u DLQ.
             */
            await AcknowledgeAsync(
                eventArgs.DeliveryTag);

            _logger.LogError(
                "Email notification {MessageId} moved to dead-letter queue {DeadLetterQueue}. Retry count: {RetryCount}.",
                messageId,
                _options.DeadLetterQueue,
                retryCount);
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "Email notification {MessageId} could not be moved to DLQ. Original delivery will be requeued.",
                messageId);

            await NegativeAcknowledgeAsync(
                eventArgs.DeliveryTag,
                requeue: true);
        }
    }

    private BasicProperties CreateForwardProperties(
        IReadOnlyBasicProperties originalProperties,
        int retryCount,
        string failureReason)
    {
        var headers =
            CloneHeaders(originalProperties.Headers);

        headers[RabbitMqHeaders.RetryCount] =
            retryCount;

        headers[RabbitMqHeaders.LastFailureReason] =
            Truncate(failureReason, 500);

        headers[RabbitMqHeaders.LastFailureAtUtc] =
            DateTime.UtcNow.ToString("O");

        headers[RabbitMqHeaders.OriginalQueue] =
            _options.EmailQueue;

        return new BasicProperties
        {
            Persistent = true,

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

            Headers = headers
        };
    }

    private static Dictionary<string, object?> CloneHeaders(
        IDictionary<string, object?>? originalHeaders)
    {
        if (originalHeaders is null)
        {
            return new Dictionary<string, object?>();
        }

        return originalHeaders.ToDictionary(
            item => item.Key,
            item => item.Value);
    }

    private static int GetRetryCount(
        IDictionary<string, object?>? headers)
    {
        if (headers is null ||
            !headers.TryGetValue(
                RabbitMqHeaders.RetryCount,
                out var value) ||
            value is null)
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

            long longValue when
                longValue <= int.MaxValue =>
                (int)longValue,

            byte[] bytes when
                int.TryParse(
                    Encoding.UTF8.GetString(bytes),
                    out var parsedValue) =>
                parsedValue,

            string stringValue when
                int.TryParse(
                    stringValue,
                    out var parsedValue) =>
                parsedValue,

            _ => 0
        };
    }

    private async Task AcknowledgeAsync(
        ulong deliveryTag)
    {
        if (_channel is null || !_channel.IsOpen)
        {
            throw new InvalidOperationException(
                "RabbitMQ channel is not available for acknowledgment.");
        }

        await _channel.BasicAckAsync(
            deliveryTag: deliveryTag,
            multiple: false,
            cancellationToken: CancellationToken.None);
    }

    private async Task NegativeAcknowledgeAsync(
        ulong deliveryTag,
        bool requeue)
    {
        if (_channel is null || !_channel.IsOpen)
        {
            _logger.LogError(
                "RabbitMQ channel is closed. Delivery {DeliveryTag} could not be negatively acknowledged.",
                deliveryTag);

            return;
        }

        try
        {
            await _channel.BasicNackAsync(
                deliveryTag: deliveryTag,
                multiple: false,
                requeue: requeue,
                cancellationToken: CancellationToken.None);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Delivery {DeliveryTag} could not be negatively acknowledged.",
                deliveryTag);
        }
    }

    private static void ValidateMessage(
        EmailNotificationMessage message)
    {
        if (message.MessageId == Guid.Empty)
        {
            throw new ArgumentException(
                "Email notification MessageId cannot be empty.");
        }

        if (message.CorrelationId == Guid.Empty)
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
            !string.IsNullOrWhiteSpace(message.Body);

        var hasTemplate =
            !string.IsNullOrWhiteSpace(
                message.TemplateName);

        if (!hasBody && !hasTemplate)
        {
            throw new ArgumentException(
                "Email notification must contain either Body or TemplateName.");
        }
    }

    private static string Truncate(
        string value,
        int maximumLength)
    {
        if (string.IsNullOrWhiteSpace(value))
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
            "RabbitMQ connection shut down. Reply code: {ReplyCode}. Reason: {Reason}.",
            eventArgs.ReplyCode,
            eventArgs.ReplyText);

        return Task.CompletedTask;
    }

    private Task OnConnectionRecoveryErrorAsync(
        object sender,
        ConnectionRecoveryErrorEventArgs eventArgs)
    {
        _logger.LogError(
            eventArgs.Exception,
            "RabbitMQ connection recovery failed.");

        return Task.CompletedTask;
    }

    private Task OnRecoverySucceededAsync(
        object sender,
        AsyncEventArgs eventArgs)
    {
        _logger.LogInformation(
            "RabbitMQ connection recovery completed successfully.");

        return Task.CompletedTask;
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Stopping notifications worker.");

        await base.StopAsync(cancellationToken);

        await DisposeRabbitMqResourcesAsync();
    }

    private async Task DisposeRabbitMqResourcesAsync()
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

        _disposed = true;

        await DisposeRabbitMqResourcesAsync();

        GC.SuppressFinalize(this);
    }
}