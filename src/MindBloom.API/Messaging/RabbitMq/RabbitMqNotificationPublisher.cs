using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.API.Messaging.Abstractions;
using MindBloom.API.Messaging.Configuration;
using MindBloom.Messaging.Contracts.Notifications;
using RabbitMQ.Client;

namespace MindBloom.API.Messaging.RabbitMq;

public sealed class RabbitMqNotificationPublisher :
    INotificationPublisher,
    IAsyncDisposable
{
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web)
        {
            WriteIndented = false
        };

    private readonly RabbitMqConnectionManager _connectionManager;
    private readonly RabbitMqOptions _options;
    private readonly ILogger<RabbitMqNotificationPublisher> _logger;

    private readonly SemaphoreSlim _channelLock = new(1, 1);

    private IChannel? _channel;
    private bool _topologyDeclared;
    private bool _disposed;

    public RabbitMqNotificationPublisher(
        RabbitMqConnectionManager connectionManager,
        IOptions<RabbitMqOptions> options,
        ILogger<RabbitMqNotificationPublisher> logger)
    {
        _connectionManager = connectionManager;
        _options = options.Value;
        _logger = logger;
    }

    public async Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(message);

        ValidateMessage(message);

        ObjectDisposedException.ThrowIf(
            _disposed,
            nameof(RabbitMqNotificationPublisher));

        await _channelLock.WaitAsync(cancellationToken);

        try
        {
            var channel = await GetChannelAsync(cancellationToken);

            var body = JsonSerializer.SerializeToUtf8Bytes(
                message,
                JsonOptions);

            var properties = new BasicProperties
            {
                ContentType = "application/json",
                ContentEncoding = "utf-8",
                Persistent = true,
                MessageId = message.MessageId.ToString(),
                CorrelationId = message.CorrelationId.ToString(),
                Type = nameof(EmailNotificationMessage),
                AppId = "MindBloom.API",
                Timestamp = new AmqpTimestamp(
                    new DateTimeOffset(
                        message.CreatedAtUtc)
                    .ToUnixTimeSeconds()),

                Headers = new Dictionary<string, object?>
                {
                    ["event-type"] =
                        message.EventType.ToString(),

                    ["retry-count"] =
                        message.RetryCount,

                    ["source"] =
                        message.Source ?? "MindBloom.API"
                }
            };

            await channel.BasicPublishAsync(
                exchange: _options.NotificationExchange,
                routingKey: _options.EmailRoutingKey,
                mandatory: true,
                basicProperties: properties,
                body: body,
                cancellationToken: cancellationToken);

            _logger.LogInformation(
                "Email notification message {MessageId} published. Event: {EventType}, recipient: {RecipientEmail}, correlation ID: {CorrelationId}.",
                message.MessageId,
                message.EventType,
                message.RecipientEmail,
                message.CorrelationId);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Failed to publish email notification message {MessageId}. Event: {EventType}, recipient: {RecipientEmail}, correlation ID: {CorrelationId}.",
                message.MessageId,
                message.EventType,
                message.RecipientEmail,
                message.CorrelationId);

            await ResetChannelAsync();

            throw;
        }
        finally
        {
            _channelLock.Release();
        }
    }

    private async Task<IChannel> GetChannelAsync(
        CancellationToken cancellationToken)
    {
        if (_channel is { IsOpen: true })
        {
            if (!_topologyDeclared)
            {
                await DeclareTopologyAsync(
                    _channel,
                    cancellationToken);
            }

            return _channel;
        }

        await ResetChannelAsync();

        var connection =
            await _connectionManager.GetConnectionAsync(
                cancellationToken);

        _channel = await connection.CreateChannelAsync(
            cancellationToken: cancellationToken);

        await DeclareTopologyAsync(
            _channel,
            cancellationToken);

        return _channel;
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

        _topologyDeclared = true;

        _logger.LogInformation(
            "RabbitMQ notification topology declared. Exchange: {Exchange}, queue: {Queue}, routing key: {RoutingKey}.",
            _options.NotificationExchange,
            _options.EmailQueue,
            _options.EmailRoutingKey);
    }

    private static void ValidateMessage(
        EmailNotificationMessage message)
    {
        if (message.MessageId == Guid.Empty)
        {
            throw new ArgumentException(
                "RabbitMQ notification MessageId cannot be empty.",
                nameof(message));
        }

        if (message.CorrelationId == Guid.Empty)
        {
            throw new ArgumentException(
                "RabbitMQ notification CorrelationId cannot be empty.",
                nameof(message));
        }

        if (message.EventType == NotificationEventType.Unknown)
        {
            throw new ArgumentException(
                "RabbitMQ notification EventType cannot be Unknown.",
                nameof(message));
        }

        if (string.IsNullOrWhiteSpace(message.RecipientEmail))
        {
            throw new ArgumentException(
                "Email notification recipient is required.",
                nameof(message));
        }

        if (string.IsNullOrWhiteSpace(message.Subject))
        {
            throw new ArgumentException(
                "Email notification subject is required.",
                nameof(message));
        }

        var hasBody = !string.IsNullOrWhiteSpace(message.Body);

        var hasTemplate =
            !string.IsNullOrWhiteSpace(message.TemplateName);

        if (!hasBody && !hasTemplate)
        {
            throw new ArgumentException(
                "Email notification must contain either Body or TemplateName.",
                nameof(message));
        }

        if (message.RetryCount < 0)
        {
            throw new ArgumentException(
                "RetryCount cannot be negative.",
                nameof(message));
        }
    }

    private async Task ResetChannelAsync()
    {
        _topologyDeclared = false;

        if (_channel is null)
        {
            return;
        }

        try
        {
            if (_channel.IsOpen)
            {
                await _channel.CloseAsync(
                    cancellationToken: CancellationToken.None);
            }
        }
        catch
        {
            // Dispose still needs to be attempted.
        }

        await _channel.DisposeAsync();
        _channel = null;
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;

        await _channelLock.WaitAsync();

        try
        {
            await ResetChannelAsync();
        }
        finally
        {
            _channelLock.Release();
            _channelLock.Dispose();
        }
    }
}