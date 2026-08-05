using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Workers;

public sealed class DeadLetterQueueMonitor
    : BackgroundService,
      IAsyncDisposable
{
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
                "RabbitMQ DLQ monitoring started. "
                + "Email DLQ: {EmailDlq}, "
                + "integration event DLQ: {IntegrationDlq}, "
                + "interval: {IntervalSeconds} seconds.",
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
                "RabbitMQ DLQ monitoring is stopping.");
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                exception,
                "RabbitMQ DLQ monitoring stopped unexpectedly.");

            throw;
        }
    }

    private async Task InitializeAsync(
        CancellationToken cancellationToken)
    {
        var factory =
            _connectionFactory.Create(
                $"{_options.ConsumerClientName}-dlq-monitor",
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
                    "Connecting DLQ monitor to RabbitMQ. "
                    + "Attempt {Attempt}/{MaximumAttempts}.",
                    attempt,
                    _options.ConnectionRetryCount);

                _connection =
                    await factory
                        .CreateConnectionAsync(
                            $"{_options.ConsumerClientName}-dlq-monitor",
                            cancellationToken);

                _channel =
                    await _connection
                        .CreateChannelAsync(
                            cancellationToken:
                                cancellationToken);

                _logger.LogInformation(
                    "RabbitMQ DLQ monitor connected successfully.");

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
                    "DLQ monitor RabbitMQ connection "
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
                "DLQ monitoring skipped because "
                + "the RabbitMQ channel is not open.");

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
                "RabbitMQ DLQ contains messages. "
                + "QueueType: {QueueType}, "
                + "Queue: {Queue}, "
                + "MessageCount: {MessageCount}, "
                + "ConsumerCount: {ConsumerCount}.",
                queueType,
                queueName,
                messageCount,
                consumerCount);

            return;
        }

        _logger.LogDebug(
            "RabbitMQ DLQ health check completed. "
            + "QueueType: {QueueType}, "
            + "Queue: {Queue}, "
            + "MessageCount: {MessageCount}.",
            queueType,
            queueName,
            messageCount);
    }

    public override async Task StopAsync(
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Stopping RabbitMQ DLQ monitor.");

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
                    exception,
                    "DLQ monitoring channel could not "
                    + "be closed cleanly.");
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
                    "DLQ monitoring connection could not "
                    + "be closed cleanly.");
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