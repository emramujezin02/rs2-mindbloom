using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Messaging.Contracts.Notifications;
using RabbitMQ.Client;

namespace MindBloom.API.Messaging.RabbitMq;

public sealed class RabbitMqNotificationPublisher :
    INotificationPublisher,
    IAsyncDisposable
{
    private const int MaximumPublishAttempts = 3;

    private static readonly TimeSpan
        InitialRetryDelay =
            TimeSpan.FromMilliseconds(300);

    private static readonly JsonSerializerOptions
        JsonOptions =
            new(JsonSerializerDefaults.Web)
            {
                WriteIndented = false
            };

    private readonly RabbitMqConnectionManager
        _connectionManager;

    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqTopology
        _topology;

    private readonly ILogger<
        RabbitMqNotificationPublisher>
        _logger;

    private readonly SemaphoreSlim
        _channelLock =
            new(1, 1);

    private IChannel? _channel;

    private bool _topologyDeclared;

    private bool _disposed;

    public RabbitMqNotificationPublisher(
        RabbitMqConnectionManager
            connectionManager,
        IOptions<RabbitMqOptions> options,
        RabbitMqTopology topology,
        ILogger<
            RabbitMqNotificationPublisher>
            logger)
    {
        _connectionManager =
            connectionManager;

        _options =
            options.Value;

        _topology =
            topology;

        _logger =
            logger;
    }

    public async Task PublishEmailAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken =
            default)
    {
        ArgumentNullException.ThrowIfNull(
            message);

        ValidateMessage(
            message);

        ObjectDisposedException.ThrowIf(
            _disposed,
            nameof(
                RabbitMqNotificationPublisher));

        await _channelLock.WaitAsync(
            cancellationToken);

        try
        {
            await PublishWithRetryAsync(
                message,
                cancellationToken);
        }
        finally
        {
            _channelLock.Release();
        }
    }

    private async Task PublishWithRetryAsync(
        EmailNotificationMessage message,
        CancellationToken cancellationToken)
    {
        Exception? lastException = null;

        for (var attempt = 1;
             attempt <= MaximumPublishAttempts;
             attempt++)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            try
            {
                var channel =
                    await GetChannelAsync(
                        cancellationToken);

                var body =
                    SerializeMessage(
                        message);

                var properties =
                    CreateProperties(
                        message);

                _logger.LogInformation(
                    "Publishing RabbitMQ message {MessageId}. Event: {EventType}, version: {MessageVersion}, correlation ID: {CorrelationId}, attempt: {Attempt}/{MaximumAttempts}.",
                    message.MessageId,
                    message.EventType,
                    message.MessageVersion,
                    message.CorrelationId,
                    attempt,
                    MaximumPublishAttempts);

                await channel.BasicPublishAsync(
                    exchange:
                        _options
                            .NotificationExchange,

                    routingKey:
                        _options
                            .EmailRoutingKey,

                    mandatory:
                        true,

                    basicProperties:
                        properties,

                    body:
                        body,

                    cancellationToken:
                        cancellationToken);

                _logger.LogInformation(
                    "RabbitMQ message {MessageId} published and confirmed successfully. Event: {EventType}, version: {MessageVersion}, correlation ID: {CorrelationId}.",
                    message.MessageId,
                    message.EventType,
                    message.MessageVersion,
                    message.CorrelationId);

                return;
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
                    "RabbitMQ publish attempt {Attempt}/{MaximumAttempts} failed for message {MessageId}. Event: {EventType}, correlation ID: {CorrelationId}.",
                    attempt,
                    MaximumPublishAttempts,
                    message.MessageId,
                    message.EventType,
                    message.CorrelationId);

                await ResetChannelAsync();

                if (attempt >=
                    MaximumPublishAttempts)
                {
                    break;
                }

                var retryDelay =
                    CalculateRetryDelay(
                        attempt);

                _logger.LogInformation(
                    "RabbitMQ message {MessageId} will be retried after {RetryDelayMilliseconds} ms.",
                    message.MessageId,
                    retryDelay
                        .TotalMilliseconds);

                await Task.Delay(
                    retryDelay,
                    cancellationToken);
            }
        }

        _logger.LogError(
            lastException,
            "RabbitMQ message {MessageId} could not be published after {MaximumAttempts} attempts. Event: {EventType}, correlation ID: {CorrelationId}.",
            message.MessageId,
            MaximumPublishAttempts,
            message.EventType,
            message.CorrelationId);

        throw new InvalidOperationException(
            $"RabbitMQ message '{message.MessageId}' could not be published after {MaximumPublishAttempts} attempts.",
            lastException);
    }

    private static byte[] SerializeMessage(
        EmailNotificationMessage message)
    {
        return JsonSerializer
            .SerializeToUtf8Bytes(
                message,
                JsonOptions);
    }

    private static BasicProperties
        CreateProperties(
            EmailNotificationMessage message)
    {
        return new BasicProperties
        {
            ContentType =
                "application/json",

            ContentEncoding =
                "utf-8",

            Persistent =
                true,

            MessageId =
                message.MessageId
                    .ToString(),

            CorrelationId =
                message.CorrelationId
                    .ToString(),

            Type =
                nameof(
                    EmailNotificationMessage),

            AppId =
                message.Source
                ?? "MindBloom.API",

            Timestamp =
                new AmqpTimestamp(
                    new DateTimeOffset(
                        message
                            .CreatedAtUtc)
                    .ToUnixTimeSeconds()),

            Headers =
                new Dictionary<
                    string,
                    object?>
                {
                    ["event-type"] =
                        message.EventType
                            .ToString(),

                    ["message-version"] =
                        message
                            .MessageVersion,

                    ["retry-count"] =
                        message.RetryCount,

                    ["source"] =
                        message.Source
                        ?? "MindBloom.API"
                }
        };
    }

    private async Task<IChannel>
        GetChannelAsync(
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
            await _connectionManager
                .GetConnectionAsync(
                    cancellationToken);

        var channelOptions =
            new CreateChannelOptions(
                publisherConfirmationsEnabled:
                    true,
                publisherConfirmationTrackingEnabled:
                    true);

        _channel =
            await connection
                .CreateChannelAsync(
                    channelOptions,
                    cancellationToken);

        await DeclareTopologyAsync(
            _channel,
            cancellationToken);

        return _channel;
    }

    private async Task DeclareTopologyAsync(
        IChannel channel,
        CancellationToken cancellationToken)
    {
        await _topology.DeclareAsync(
            channel,
            cancellationToken);

        _topologyDeclared =
            true;
    }

    private static TimeSpan
        CalculateRetryDelay(
            int failedAttempt)
    {
        var multiplier =
            Math.Pow(
                2,
                failedAttempt - 1);

        return TimeSpan
            .FromMilliseconds(
                InitialRetryDelay
                    .TotalMilliseconds
                *
                multiplier);
    }

    private static void ValidateMessage(
        EmailNotificationMessage message)
    {
        if (message.MessageId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "RabbitMQ notification MessageId cannot be empty.",
                nameof(message));
        }

        if (message.CorrelationId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "RabbitMQ notification CorrelationId cannot be empty.",
                nameof(message));
        }

        if (message.EventType ==
            NotificationEventType.Unknown)
        {
            throw new ArgumentException(
                "RabbitMQ notification EventType cannot be Unknown.",
                nameof(message));
        }

        if (message.MessageVersion <= 0)
        {
            throw new ArgumentException(
                "RabbitMQ notification MessageVersion must be greater than zero.",
                nameof(message));
        }

        if (string.IsNullOrWhiteSpace(
                message.RecipientEmail))
        {
            throw new ArgumentException(
                "Email notification recipient is required.",
                nameof(message));
        }

        if (string.IsNullOrWhiteSpace(
                message.Subject))
        {
            throw new ArgumentException(
                "Email notification subject is required.",
                nameof(message));
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
        _topologyDeclared =
            false;

        if (_channel is null)
        {
            return;
        }

        try
        {
            if (_channel.IsOpen)
            {
                await _channel.CloseAsync(
                    cancellationToken:
                        CancellationToken.None);
            }
        }
        catch
        {
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

        _disposed =
            true;

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

        GC.SuppressFinalize(this);
    }
}