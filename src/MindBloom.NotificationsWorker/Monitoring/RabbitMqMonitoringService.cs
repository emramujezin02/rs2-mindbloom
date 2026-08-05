using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Monitoring;

public sealed class RabbitMqMonitoringService
    : BackgroundService,
      IAsyncDisposable
{
    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly RabbitMqTopology
        _topology;

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
        RabbitMqConnectionFactory
            connectionFactory,
        RabbitMqTopology topology,
        RabbitMqMonitoringMetrics metrics,
        ILogger<RabbitMqMonitoringService>
            logger)
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
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        try
        {
            await InitializeAsync(
                stoppingToken);

            _logger.LogInformation(
                "RabbitMQ monitoring started. "
                + "Interval: {IntervalSeconds} seconds.",
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
                "RabbitMQ monitoring is stopping.");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "RabbitMQ monitoring stopped unexpectedly.");

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
                    "Connecting RabbitMQ monitoring service. "
                    + "Attempt {Attempt}/{MaximumAttempts}.",
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
                    "RabbitMQ monitoring connection established successfully.");

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
                    "RabbitMQ monitoring connection "
                    + "attempt {Attempt}/{MaximumAttempts} failed.",
                    attempt,
                    _options.ConnectionRetryCount);

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
                "RabbitMQ monitoring skipped because the channel is not open.");

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
            "RabbitMQ monitoring snapshot. "
            + "EmailQueueLength: {EmailQueueLength}, "
            + "EmailConsumers: {EmailConsumers}, "
            + "IntegrationQueueLength: {IntegrationQueueLength}, "
            + "IntegrationConsumers: {IntegrationConsumers}, "
            + "EmailRetryQueueMessages: {EmailRetryQueueMessages}, "
            + "IntegrationRetryQueueMessages: {IntegrationRetryQueueMessages}, "
            + "EmailDlqMessages: {EmailDlqMessages}, "
            + "IntegrationDlqMessages: {IntegrationDlqMessages}, "
            + "FailedMessagesTotal: {FailedMessagesTotal}, "
            + "RetryCountTotal: {RetryCountTotal}, "
            + "SuccessCountTotal: {SuccessCountTotal}, "
            + "ThroughputPerMinute: {ThroughputPerMinute:F2}.",
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
            throughputPerMinute);

        if (failedMessagesInQueues > 0)
        {
            _logger.LogWarning(
                "RabbitMQ contains failed messages in DLQ. "
                + "Total DLQ messages: {FailedMessagesInQueues}.",
                failedMessagesInQueues);
        }

        if (totalRetryMessagesInQueues > 0)
        {
            _logger.LogWarning(
                "RabbitMQ currently contains {RetryMessages} message(s) waiting in retry queues.",
                totalRetryMessagesInQueues);
        }

        if (emailQueue.ConsumerCount == 0)
        {
            _logger.LogWarning(
                "RabbitMQ email queue {Queue} currently has no active consumers.",
                _options.EmailQueue);
        }

        if (integrationQueue.ConsumerCount == 0)
        {
            _logger.LogWarning(
                "RabbitMQ integration event queue {Queue} currently has no active consumers.",
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
            "Stopping RabbitMQ monitoring service.");

        await base.StopAsync(
            cancellationToken);

        await DisposeRabbitMqResourcesAsync();

        _logger.LogInformation(
            "RabbitMQ monitoring service stopped successfully.");
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
                    "RabbitMQ monitoring channel could not be closed cleanly.");
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
                    exception,
                    "RabbitMQ monitoring connection could not be closed cleanly.");
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