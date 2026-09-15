using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;
using MindBloom.Shared.Observability;

namespace MindBloom.NotificationsWorker.Monitoring;

public sealed class RabbitMqMonitoringService
    : BackgroundService,
      IAsyncDisposable
{
    private static readonly EventId
    MonitoringStartedEvent =
        new(
            4600,
            "RabbitMqMonitoringStarted");

    private static readonly EventId
        MonitoringStoppingEvent =
            new(
                4601,
                "RabbitMqMonitoringStopping");

    private static readonly EventId
        MonitoringFailedEvent =
            new(
                4602,
                "RabbitMqMonitoringFailed");

    private static readonly EventId
        ConnectionAttemptEvent =
            new(
                4610,
                "RabbitMqMonitoringConnectionAttempt");

    private static readonly EventId
        ConnectionEstablishedEvent =
            new(
                4611,
                "RabbitMqMonitoringConnectionEstablished");

    private static readonly EventId
        ConnectionAttemptFailedEvent =
            new(
                4612,
                "RabbitMqMonitoringConnectionAttemptFailed");

    private static readonly EventId
        MonitoringSkippedEvent =
            new(
                4620,
                "RabbitMqMonitoringSkipped");

    private static readonly EventId
        MonitoringSnapshotEvent =
            new(
                4621,
                "RabbitMqMonitoringSnapshot");

    private static readonly EventId
        DeadLetterMessagesDetectedEvent =
            new(
                4622,
                "RabbitMqDeadLetterMessagesDetected");

    private static readonly EventId
        RetryMessagesDetectedEvent =
            new(
                4623,
                "RabbitMqRetryMessagesDetected");

    private static readonly EventId
        EmailConsumersMissingEvent =
            new(
                4624,
                "RabbitMqEmailConsumersMissing");

    private static readonly EventId
        IntegrationConsumersMissingEvent =
            new(
                4625,
                "RabbitMqIntegrationConsumersMissing");

    private static readonly EventId
        MonitoringStopRequestedEvent =
            new(
                4630,
                "RabbitMqMonitoringStopRequested");

    private static readonly EventId
        MonitoringStoppedEvent =
            new(
                4631,
                "RabbitMqMonitoringStopped");

    private static readonly EventId
        ChannelCloseFailedEvent =
            new(
                4640,
                "RabbitMqMonitoringChannelCloseFailed");

    private static readonly EventId
        ConnectionCloseFailedEvent =
            new(
                4641,
                "RabbitMqMonitoringConnectionCloseFailed");

    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly RabbitMqTopology
        _topology;

    private readonly ApplicationMetrics
    _applicationMetrics;

    private readonly RabbitMqMonitoringMetrics
        _metrics;

    private readonly ILogger<
        RabbitMqMonitoringService>
        _logger;

    private IConnection? _connection;

    private IChannel? _channel;

    private long _previousSuccessfulMessages;

    private DateTime _previousSampleUtc =
        DateTime.UtcNow;

    private bool _disposed;

    public RabbitMqMonitoringService(
        IOptions<RabbitMqOptions> options,
        RabbitMqConnectionFactory connectionFactory,
        RabbitMqTopology topology,
        RabbitMqMonitoringMetrics metrics,
        ApplicationMetrics applicationMetrics,
        ILogger<RabbitMqMonitoringService> logger)
    {
        _options =
            options.Value;

        _connectionFactory =
            connectionFactory;

        _topology =
            topology;

        _metrics =
            metrics;

        _logger =
            logger;

        _applicationMetrics =
    applicationMetrics;
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
                "RabbitMQ monitoring started. Module: {Module}, IntervalSeconds: {IntervalSeconds}.",
                "RabbitMQMonitoring",
                _options
                    .MonitoringIntervalSeconds);

            while (!stoppingToken
                       .IsCancellationRequested)
            {
                await CollectMetricsAsync(
                    stoppingToken);

                await Task.Delay(
                    TimeSpan.FromSeconds(
                        _options
                            .MonitoringIntervalSeconds),
                    stoppingToken);
            }
        }
        catch (OperationCanceledException)
            when (stoppingToken
                .IsCancellationRequested)
        {
            _logger.LogInformation(
                MonitoringStoppingEvent,
                "RabbitMQ monitoring is stopping. Module: {Module}.",
                "RabbitMQMonitoring");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                MonitoringFailedEvent,
                "RabbitMQ monitoring stopped unexpectedly. Module: {Module}, FailureType: {FailureType}.",
                "RabbitMQMonitoring",
                exception.GetType().Name);

            throw;
        }
    }

    private async Task InitializeAsync(
        CancellationToken cancellationToken)
    {
        var clientName =
            $"{_options.ConsumerClientName}-monitor";

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
                    "RabbitMQ monitoring connection attempt. Module: {Module}, Client: {Client}, Host: {HostName}, Port: {Port}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    "RabbitMQMonitoring",
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

                await _topology.DeclareAsync(
                    _channel,
                    cancellationToken);

                _logger.LogInformation(
                    ConnectionEstablishedEvent,
                    "RabbitMQ monitoring connection established successfully. Module: {Module}, Client: {Client}.",
                    "RabbitMQMonitoring",
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
                    "RabbitMQ monitoring connection attempt failed. Module: {Module}, Client: {Client}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}, FailureType: {FailureType}.",
                    "RabbitMQMonitoring",
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
            "RabbitMQ monitoring service could not establish a connection.",
            lastException);
    }

    private async Task CollectMetricsAsync(
        CancellationToken cancellationToken)
    {
        if (_channel is null ||
            !_channel.IsOpen)
        {
            _logger.LogWarning(
                MonitoringSkippedEvent,
                "RabbitMQ monitoring skipped because the channel is not open. Module: {Module}.",
                "RabbitMQMonitoring");

            return;
        }

        var emailQueue =
            await GetQueueSnapshotAsync(
                _options.EmailQueue,
                cancellationToken);

        var integrationQueue =
            await GetQueueSnapshotAsync(
                _options.IntegrationEventQueue,
                cancellationToken);

        var emailDlq =
            await GetQueueSnapshotAsync(
                _options.DeadLetterQueue,
                cancellationToken);

        var integrationDlq =
            await GetQueueSnapshotAsync(
                _options
                    .IntegrationEventDeadLetterQueue,
                cancellationToken);

        _applicationMetrics.SetDlqDepth(
    "Email",
    emailDlq.MessageCount);

        _applicationMetrics.SetDlqDepth(
            "IntegrationEvent",
            integrationDlq.MessageCount);

        var emailRetryMessages =
            await GetEmailRetryMessageCountAsync(
                cancellationToken);

        var integrationRetryMessages =
            await GetIntegrationRetryMessageCountAsync(
                cancellationToken);

        var now =
            DateTime.UtcNow;

        var currentSuccessfulMessages =
            _metrics.SuccessfulMessages;

        var successfulSinceLastSample =
            Math.Max(
                0,
                currentSuccessfulMessages -
                _previousSuccessfulMessages);

        var elapsed =
            now -
            _previousSampleUtc;

        var throughputPerMinute =
            elapsed.TotalSeconds <= 0
                ? 0
                : successfulSinceLastSample /
                  elapsed.TotalMinutes;

        _previousSuccessfulMessages =
            currentSuccessfulMessages;

        _previousSampleUtc =
            now;

        var failedMessagesInQueues =
            (long)emailDlq.MessageCount +
            integrationDlq.MessageCount;

        var totalRetryMessagesInQueues =
            emailRetryMessages +
            integrationRetryMessages;

        _logger.LogInformation(
            MonitoringSnapshotEvent,
            "RabbitMQ monitoring snapshot. Module: {Module}, EmailQueueLength: {EmailQueueLength}, EmailConsumers: {EmailConsumers}, IntegrationQueueLength: {IntegrationQueueLength}, IntegrationConsumers: {IntegrationConsumers}, EmailRetryQueueMessages: {EmailRetryQueueMessages}, IntegrationRetryQueueMessages: {IntegrationRetryQueueMessages}, EmailDlqMessages: {EmailDlqMessages}, IntegrationDlqMessages: {IntegrationDlqMessages}, FailedMessagesTotal: {FailedMessagesTotal}, RetryCountTotal: {RetryCountTotal}, SuccessCountTotal: {SuccessCountTotal}, ThroughputPerMinute: {ThroughputPerMinute}.",
            "RabbitMQMonitoring",
            emailQueue.MessageCount,
            emailQueue.ConsumerCount,
            integrationQueue.MessageCount,
            integrationQueue.ConsumerCount,
            emailRetryMessages,
            integrationRetryMessages,
            emailDlq.MessageCount,
            integrationDlq.MessageCount,
            _metrics.FailedMessages,
            _metrics.RetryCount,
            _metrics.SuccessfulMessages,
            Math.Round(
                throughputPerMinute,
                2));

        if (failedMessagesInQueues > 0)
        {
            _logger.LogWarning(
                DeadLetterMessagesDetectedEvent,
                "RabbitMQ contains failed messages in DLQ. Module: {Module}, FailedMessagesInQueues: {FailedMessagesInQueues}.",
                "RabbitMQMonitoring",
                failedMessagesInQueues);
        }

        if (totalRetryMessagesInQueues > 0)
        {
            _logger.LogWarning(
                RetryMessagesDetectedEvent,
                "RabbitMQ currently contains messages waiting in retry queues. Module: {Module}, RetryMessages: {RetryMessages}.",
                "RabbitMQMonitoring",
                totalRetryMessagesInQueues);
        }

        if (emailQueue.ConsumerCount == 0)
        {
            _logger.LogWarning(
                EmailConsumersMissingEvent,
                "RabbitMQ email queue currently has no active consumers. Module: {Module}, Queue: {Queue}.",
                "RabbitMQMonitoring",
                _options.EmailQueue);
        }

        if (integrationQueue.ConsumerCount == 0)
        {
            _logger.LogWarning(
                IntegrationConsumersMissingEvent,
                "RabbitMQ integration event queue currently has no active consumers. Module: {Module}, Queue: {Queue}.",
                "RabbitMQMonitoring",
                _options.IntegrationEventQueue);
        }
    }

    private async Task<QueueSnapshot>
        GetQueueSnapshotAsync(
            string queueName,
            CancellationToken cancellationToken)
    {
        var result =
            await _channel!
                .QueueDeclarePassiveAsync(
                    queueName,
                    cancellationToken);

        return new QueueSnapshot(
            result.MessageCount,
            result.ConsumerCount);
    }

    private async Task<long>
        GetEmailRetryMessageCountAsync(
            CancellationToken cancellationToken)
    {
        long total =
            0;

        foreach (var delayMilliseconds
                 in _topology.RetryDelays)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            var queueName =
                _topology.GetRetryQueueName(
                    delayMilliseconds);

            var snapshot =
                await GetQueueSnapshotAsync(
                    queueName,
                    cancellationToken);

            total +=
                snapshot.MessageCount;
        }

        return total;
    }

    private async Task<long>
        GetIntegrationRetryMessageCountAsync(
            CancellationToken cancellationToken)
    {
        long total =
            0;

        foreach (var routingKey
                 in _topology
                     .SupportedIntegrationEventRoutingKeys)
        {
            foreach (var delayMilliseconds
                     in _topology.RetryDelays)
            {
                cancellationToken
                    .ThrowIfCancellationRequested();

                var sourceQueue =
                    _options
                        .IntegrationEventQueue
                    + "."
                    + routingKey;

                var queueName =
                    _topology
                        .GetRetryQueueName(
                            sourceQueue,
                            delayMilliseconds);

                var snapshot =
                    await GetQueueSnapshotAsync(
                        queueName,
                        cancellationToken);

                total +=
                    snapshot.MessageCount;
            }
        }

        return total;
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            MonitoringStopRequestedEvent,
            "Stopping RabbitMQ monitoring service. Module: {Module}.",
            "RabbitMQMonitoring");

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();

        _logger.LogInformation(
            MonitoringStoppedEvent,
            "RabbitMQ monitoring service stopped successfully. Module: {Module}.",
            "RabbitMQMonitoring");
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
    "RabbitMQ monitoring channel could not be closed cleanly. Module: {Module}.",
    "RabbitMQMonitoring");
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
     "RabbitMQ monitoring connection could not be closed cleanly. Module: {Module}.",
     "RabbitMQMonitoring");
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

    private sealed record QueueSnapshot(
        uint MessageCount,
        uint ConsumerCount);
}