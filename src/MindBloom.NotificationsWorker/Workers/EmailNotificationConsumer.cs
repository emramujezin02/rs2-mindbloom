using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.NotificationsWorker.Configuration;
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
    private bool _disposed;

    public EmailNotificationConsumer(
        IOptions<RabbitMqConsumerOptions> options,
        IEmailService emailService,
        EmailMessageBodyBuilder bodyBuilder,
        ILogger<EmailNotificationConsumer> logger)
    {
        _options = options.Value;
        _emailService = emailService;
        _bodyBuilder = bodyBuilder;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        try
        {
            await InitializeRabbitMqAsync(stoppingToken);

            var consumer = new AsyncEventingBasicConsumer(_channel!);

            consumer.ReceivedAsync += HandleMessageAsync;

            var consumerTag = await _channel!.BasicConsumeAsync(
                queue: _options.EmailQueue,
                autoAck: false,
                consumer: consumer,
                cancellationToken: stoppingToken);

            _logger.LogInformation(
                "Notifications worker started consuming RabbitMQ queue {Queue}. Consumer tag: {ConsumerTag}.",
                _options.EmailQueue,
                consumerTag);

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
                "Notifications worker stopped because RabbitMQ consumer initialization failed.");

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

            NetworkRecoveryInterval = TimeSpan.FromSeconds(
                _options.NetworkRecoveryIntervalSeconds),

            RequestedHeartbeat = TimeSpan.FromSeconds(
                _options.RequestedHeartbeatSeconds),

            ConsumerDispatchConcurrency = 1
        };

        _logger.LogInformation(
            "Connecting notifications worker to RabbitMQ at {HostName}:{Port}.",
            _options.HostName,
            _options.Port);

        _connection = await factory.CreateConnectionAsync(
            _options.ClientProvidedName,
            cancellationToken);

        _connection.ConnectionShutdownAsync +=
            OnConnectionShutdownAsync;

        _connection.ConnectionRecoveryErrorAsync +=
            OnConnectionRecoveryErrorAsync;

        _connection.RecoverySucceededAsync +=
            OnRecoverySucceededAsync;

        _channel = await _connection.CreateChannelAsync(
            cancellationToken: cancellationToken);

        await DeclareTopologyAsync(
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

    private async Task DeclareTopologyAsync(
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

        await channel.QueueDeclareAsync(
            queue: _options.EmailQueue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: null,
            cancellationToken: cancellationToken);

        await channel.QueueBindAsync(
            queue: _options.EmailQueue,
            exchange: _options.NotificationExchange,
            routingKey: _options.EmailRoutingKey,
            arguments: null,
            cancellationToken: cancellationToken);

        _logger.LogInformation(
            "RabbitMQ topology declared. Exchange: {Exchange}, queue: {Queue}, routing key: {RoutingKey}.",
            _options.NotificationExchange,
            _options.EmailQueue,
            _options.EmailRoutingKey);
    }

    private async Task HandleMessageAsync(
        object sender,
        BasicDeliverEventArgs eventArgs)
    {
        if (_channel is null || !_channel.IsOpen)
        {
            _logger.LogError(
                "RabbitMQ channel is unavailable while processing delivery {DeliveryTag}.",
                eventArgs.DeliveryTag);

            return;
        }

        EmailNotificationMessage? message = null;

        try
        {
            message = JsonSerializer.Deserialize<EmailNotificationMessage>(
                eventArgs.Body.Span,
                JsonOptions);

            if (message is null)
            {
                throw new JsonException(
                    "RabbitMQ email notification message could not be deserialized.");
            }

            ValidateMessage(message);

            _logger.LogInformation(
                "Processing email notification {MessageId}. Event: {EventType}, recipient: {RecipientEmail}, correlation ID: {CorrelationId}.",
                message.MessageId,
                message.EventType,
                message.RecipientEmail,
                message.CorrelationId);

            var emailBody = _bodyBuilder.Build(message);

            await _emailService.SendAsync(
                message.RecipientEmail,
                message.Subject,
                emailBody);

            /*
             * ACK se šalje tek nakon što SendAsync uspješno završi.
             * Ako slanje emaila baci exception, ovaj dio se ne izvršava.
             */
            await _channel.BasicAckAsync(
                deliveryTag: eventArgs.DeliveryTag,
                multiple: false,
                cancellationToken: CancellationToken.None);

            _logger.LogInformation(
                "Email notification {MessageId} sent successfully and acknowledged.",
                message.MessageId);
        }
        catch (JsonException exception)
        {
            _logger.LogError(
                exception,
                "RabbitMQ message with delivery tag {DeliveryTag} contains invalid JSON and cannot be processed.",
                eventArgs.DeliveryTag);

            /*
             * Neispravan JSON se ne vraća u isti red jer ga ponovno
             * preuzimanje ne bi moglo popraviti.
             */
            await RejectMessageAsync(
                eventArgs.DeliveryTag,
                requeue: false);
        }
        catch (ArgumentException exception)
        {
            _logger.LogError(
                exception,
                "RabbitMQ email message {MessageId} contains invalid data.",
                message?.MessageId);

            await RejectMessageAsync(
                eventArgs.DeliveryTag,
                requeue: false);
        }
        catch (InvalidOperationException exception)
        {
            _logger.LogError(
                exception,
                "RabbitMQ email message {MessageId} could not be rendered.",
                message?.MessageId);

            await RejectMessageAsync(
                eventArgs.DeliveryTag,
                requeue: false);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Sending email notification {MessageId} failed. The message will be returned to the queue.",
                message?.MessageId);

            /*
             * SMTP ili druga privremena greška:
             * poruka se trenutno vraća u queue.
             *
             * Kontrolirani retry i dead-letter queue će se obično
             * implementirati u narednom tasku.
             */
            await RejectMessageAsync(
                eventArgs.DeliveryTag,
                requeue: true);
        }
    }

    private async Task RejectMessageAsync(
        ulong deliveryTag,
        bool requeue)
    {
        if (_channel is null || !_channel.IsOpen)
        {
            _logger.LogError(
                "RabbitMQ channel is closed and delivery {DeliveryTag} could not be rejected.",
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
                "RabbitMQ delivery {DeliveryTag} could not be negatively acknowledged.",
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

        if (message.EventType == NotificationEventType.Unknown)
        {
            throw new ArgumentException(
                "Email notification EventType cannot be Unknown.");
        }

        if (string.IsNullOrWhiteSpace(message.RecipientEmail))
        {
            throw new ArgumentException(
                "Email notification recipient is required.");
        }

        if (string.IsNullOrWhiteSpace(message.Subject))
        {
            throw new ArgumentException(
                "Email notification subject is required.");
        }

        var hasBody =
            !string.IsNullOrWhiteSpace(message.Body);

        var hasTemplate =
            !string.IsNullOrWhiteSpace(message.TemplateName);

        if (!hasBody && !hasTemplate)
        {
            throw new ArgumentException(
                "Email notification must contain either Body or TemplateName.");
        }

        if (message.RetryCount < 0)
        {
            throw new ArgumentException(
                "Email notification RetryCount cannot be negative.");
        }
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