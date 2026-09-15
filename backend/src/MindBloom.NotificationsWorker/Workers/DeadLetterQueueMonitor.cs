using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class DeadLetterQueueMonitor
    : BackgroundService,
      IAsyncDisposable
{
    private static readonly EventId
    MonitoringStartedEvent =
        new(
            4900,
            "DeadLetterQueueMonitoringStarted");

    private static readonly EventId
        MonitoringStoppingEvent =
            new(
                4901,
                "DeadLetterQueueMonitoringStopping");

    private static readonly EventId
        MonitoringFailedEvent =
            new(
                4902,
                "DeadLetterQueueMonitoringFailed");

    private static readonly EventId
        ConnectionAttemptEvent =
            new(
                4910,
                "DeadLetterQueueConnectionAttempt");

    private static readonly EventId
        ConnectionEstablishedEvent =
            new(
                4911,
                "DeadLetterQueueConnectionEstablished");

    private static readonly EventId
        ConnectionAttemptFailedEvent =
            new(
                4912,
                "DeadLetterQueueConnectionAttemptFailed");

    private static readonly EventId
        MonitoringSkippedEvent =
            new(
                4920,
                "DeadLetterQueueMonitoringSkipped");

    private static readonly EventId
        MessagesDetectedEvent =
            new(
                4921,
                "DeadLetterQueueMessagesDetected");

    private static readonly EventId
        HealthCheckCompletedEvent =
            new(
                4922,
                "DeadLetterQueueHealthCheckCompleted");

    private static readonly EventId
        MonitoringStopRequestedEvent =
            new(
                4930,
                "DeadLetterQueueMonitoringStopRequested");

    private static readonly EventId
        ChannelCloseFailedEvent =
            new(
                4940,
                "DeadLetterQueueChannelCloseFailed");

    private static readonly EventId
        ConnectionCloseFailedEvent =
            new(
                4941,
                "DeadLetterQueueConnectionCloseFailed");

    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly ILogger<
        DeadLetterQueueMonitor>
        _logger;

    private IConnection? _connection;

    private IChannel? _channel;

    private bool _disposed;

    public DeadLetterQueueMonitor(
        IOptions<RabbitMqOptions> options,
        RabbitMqConnectionFactory
            connectionFactory,
        ILogger<DeadLetterQueueMonitor>
            logger)
    {
        _options =
            options.Value;

        _connectionFactory =
            connectionFactory;

        _logger =
            logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        try
        {
            await InitializeAsync(
                stoppingToken);

            _logger.LogInformation(
                MonitoringStartedEvent,
                "RabbitMQ DLQ monitoring started. Module: {Module}, EmailDlq: {EmailDlq}, IntegrationDlq: {IntegrationDlq}, IntervalSeconds: {IntervalSeconds}.",
                "DeadLetterQueueMonitoring",
                _options.DeadLetterQueue,
                _options
                    .IntegrationEventDeadLetterQueue,
                _options
                    .DeadLetterMonitoringIntervalSeconds);

            while (!stoppingToken
                       .IsCancellationRequested)
            {
                await CheckQueuesAsync(
                    stoppingToken);

                await Task.Delay(
                    TimeSpan.FromSeconds(
                        _options
                            .DeadLetterMonitoringIntervalSeconds),
                    stoppingToken);
            }
        }
        catch (OperationCanceledException)
            when (stoppingToken
                .IsCancellationRequested)
        {
            _logger.LogInformation(
                MonitoringStoppingEvent,
                "RabbitMQ DLQ monitoring is stopping. Module: {Module}.",
                "DeadLetterQueueMonitoring");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                MonitoringFailedEvent,
                "RabbitMQ DLQ monitoring stopped unexpectedly. Module: {Module}, FailureType: {FailureType}.",
                "DeadLetterQueueMonitoring",
                exception.GetType().Name);

            throw;
        }
    }

    private async Task InitializeAsync(
        CancellationToken cancellationToken)
    {
        var clientName =
            $"{_options.ConsumerClientName}-dlq-monitor";

        var factory =
            _connectionFactory.Create(
                clientName,
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
                    ConnectionAttemptEvent,
                    "Connecting DLQ monitor to RabbitMQ. Module: {Module}, Client: {Client}, Host: {HostName}, Port: {Port}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    "DeadLetterQueueMonitoring",
                    clientName,
                    _options.HostName,
                    _options.Port,
                    attempt,
                    _options.ConnectionRetryCount);

                _connection =
                    await factory
                        .CreateConnectionAsync(
                            clientName,
                            cancellationToken);

                _channel =
                    await _connection
                        .CreateChannelAsync(
                            cancellationToken:
                                cancellationToken);

                _logger.LogInformation(
                    ConnectionEstablishedEvent,
                    "RabbitMQ DLQ monitor connected successfully. Module: {Module}, Client: {Client}.",
                    "DeadLetterQueueMonitoring",
                    clientName);

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
                    ConnectionAttemptFailedEvent,
                    "DLQ monitor RabbitMQ connection attempt failed. Module: {Module}, Client: {Client}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}, FailureType: {FailureType}.",
                    "DeadLetterQueueMonitoring",
                    clientName,
                    attempt,
                    _options.ConnectionRetryCount,
                    exception.GetType().Name);

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
            "DLQ monitor could not establish "
            + "a RabbitMQ connection.",
            lastException);
    }

    private async Task CheckQueuesAsync(
        CancellationToken cancellationToken)
    {
        if (_channel is null ||
            !_channel.IsOpen)
        {
            _logger.LogWarning(
                MonitoringSkippedEvent,
                "DLQ monitoring skipped because the RabbitMQ channel is not open. Module: {Module}.",
                "DeadLetterQueueMonitoring");

            return;
        }

        await CheckQueueAsync(
            _options.DeadLetterQueue,
            "Email",
            cancellationToken);

        await CheckQueueAsync(
            _options
                .IntegrationEventDeadLetterQueue,
            "IntegrationEvent",
            cancellationToken);
    }

    private async Task CheckQueueAsync(
        string queueName,
        string queueType,
        CancellationToken cancellationToken)
    {
        var result =
            await _channel!
                .QueueDeclarePassiveAsync(
                    queueName,
                    cancellationToken);

        var messageCount =
            result.MessageCount;

        var consumerCount =
            result.ConsumerCount;

        if (messageCount >=
            _options
                .DeadLetterWarningMessageCount &&
            messageCount > 0)
        {
            _logger.LogWarning(
                MessagesDetectedEvent,
                "RabbitMQ DLQ contains messages. Module: {Module}, QueueType: {QueueType}, Queue: {Queue}, MessageCount: {MessageCount}, ConsumerCount: {ConsumerCount}.",
                "DeadLetterQueueMonitoring",
                queueType,
                queueName,
                messageCount,
                consumerCount);

            return;
        }

        _logger.LogDebug(
            HealthCheckCompletedEvent,
            "RabbitMQ DLQ health check completed. Module: {Module}, QueueType: {QueueType}, Queue: {Queue}, MessageCount: {MessageCount}.",
            "DeadLetterQueueMonitoring",
            queueType,
            queueName,
            messageCount);
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            MonitoringStopRequestedEvent,
            "Stopping RabbitMQ DLQ monitor. Module: {Module}.",
            "DeadLetterQueueMonitoring");

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();
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
                    "DLQ monitoring channel could not be closed cleanly. Module: {Module}.",
                    "DeadLetterQueueMonitoring");
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
                    "DLQ monitoring connection could not be closed cleanly. Module: {Module}.",
                    "DeadLetterQueueMonitoring");
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