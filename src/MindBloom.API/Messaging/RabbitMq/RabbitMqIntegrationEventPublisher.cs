using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Messaging.Contracts.Common;
using RabbitMQ.Client;

namespace MindBloom.API.Messaging.RabbitMq;

public sealed class RabbitMqIntegrationEventPublisher
    : IIntegrationEventPublisher,
      IAsyncDisposable
{
    private const int MaximumPublishAttempts =
        3;

    private static readonly TimeSpan
        InitialRetryDelay =
            TimeSpan.FromMilliseconds(
                300);

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
        RabbitMqIntegrationEventPublisher>
        _logger;

    private readonly SemaphoreSlim
        _channelLock =
            new(1, 1);

    private IChannel? _channel;

    private bool _topologyDeclared;

    private bool _disposed;

    public RabbitMqIntegrationEventPublisher(
        RabbitMqConnectionManager connectionManager,
        IOptions<RabbitMqOptions> options,
        RabbitMqTopology topology,
        ILogger<
            RabbitMqIntegrationEventPublisher>
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

    public async Task PublishAsync<TEvent>(
        TEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken =
            default)
        where TEvent : IntegrationEvent
    {
        ArgumentNullException.ThrowIfNull(
            integrationEvent);

        if (string.IsNullOrWhiteSpace(
                routingKey))
        {
            throw new ArgumentException(
                "RabbitMQ routing key is required.",
                nameof(routingKey));
        }

        ValidateEvent(
            integrationEvent);

        ObjectDisposedException.ThrowIf(
            _disposed,
            nameof(
                RabbitMqIntegrationEventPublisher));

        await _channelLock.WaitAsync(
            cancellationToken);

        try
        {
            await PublishWithRetryAsync(
                integrationEvent,
                routingKey.Trim(),
                cancellationToken);
        }
        finally
        {
            _channelLock.Release();
        }
    }

    private async Task PublishWithRetryAsync<TEvent>(
        TEvent integrationEvent,
        string routingKey,
        CancellationToken cancellationToken)
        where TEvent : IntegrationEvent
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
                    JsonSerializer
                        .SerializeToUtf8Bytes(
                            integrationEvent,
                            integrationEvent
                                .GetType(),
                            JsonOptions);

                var properties =
                    CreateProperties(
                        integrationEvent);

                _logger.LogInformation(
                    "Publishing integration event {EventId}. Type: {EventType}, version: {EventVersion}, correlation ID: {CorrelationId}, routing key: {RoutingKey}, attempt: {Attempt}/{MaximumAttempts}.",
                    integrationEvent.EventId,
                    integrationEvent
                        .GetType()
                        .Name,
                    integrationEvent.EventVersion,
                    integrationEvent.CorrelationId,
                    routingKey,
                    attempt,
                    MaximumPublishAttempts);

                await channel.BasicPublishAsync(
                    exchange:
                        _options
                            .NotificationExchange,

                    routingKey:
                        routingKey,

                    mandatory:
                        true,

                    basicProperties:
                        properties,

                    body:
                        body,

                    cancellationToken:
                        cancellationToken);

                _logger.LogInformation(
                    "Integration event {EventId} published and confirmed successfully. Type: {EventType}, correlation ID: {CorrelationId}.",
                    integrationEvent.EventId,
                    integrationEvent
                        .GetType()
                        .Name,
                    integrationEvent.CorrelationId);

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
                    "RabbitMQ integration event publish attempt {Attempt}/{MaximumAttempts} failed for event {EventId}.",
                    attempt,
                    MaximumPublishAttempts,
                    integrationEvent.EventId);

                await ResetChannelAsync();

                if (attempt >=
                    MaximumPublishAttempts)
                {
                    break;
                }

                var retryDelay =
                    CalculateRetryDelay(
                        attempt);

                await Task.Delay(
                    retryDelay,
                    cancellationToken);
            }
        }

        throw new InvalidOperationException(
            $"Integration event '{integrationEvent.EventId}' could not be published after {MaximumPublishAttempts} attempts.",
            lastException);
    }

    private static BasicProperties
        CreateProperties(
            IntegrationEvent integrationEvent)
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
                integrationEvent
                    .EventId
                    .ToString(),

            CorrelationId =
                integrationEvent
                    .CorrelationId
                    .ToString(),

            Type =
                integrationEvent
                    .GetType()
                    .Name,

            AppId =
                "MindBloom.API",

            Timestamp =
                new AmqpTimestamp(
                    new DateTimeOffset(
                        integrationEvent
                            .TimestampUtc)
                    .ToUnixTimeSeconds()),

            Headers =
                new Dictionary<
                    string,
                    object?>
                {
                    ["event-version"] =
                        integrationEvent
                            .EventVersion
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

    private static void ValidateEvent(
        IntegrationEvent integrationEvent)
    {
        if (integrationEvent.EventId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "Integration event EventId cannot be empty.",
                nameof(integrationEvent));
        }

        if (integrationEvent.CorrelationId ==
            Guid.Empty)
        {
            throw new ArgumentException(
                "Integration event CorrelationId cannot be empty.",
                nameof(integrationEvent));
        }

        if (integrationEvent.EventVersion <= 0)
        {
            throw new ArgumentException(
                "Integration event EventVersion must be greater than zero.",
                nameof(integrationEvent));
        }

        if (integrationEvent.TimestampUtc ==
            default)
        {
            throw new ArgumentException(
                "Integration event TimestampUtc is required.",
                nameof(integrationEvent));
        }
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

    private async Task
        ResetChannelAsync()
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