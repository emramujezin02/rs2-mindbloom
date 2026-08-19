using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace MindBloom.NotificationsWorker.Messaging;

public sealed class RabbitMqWorkerConnectionProvider
{
    private static readonly EventId
    ConnectionAttemptEvent =
        new(
            4200,
            "RabbitMqWorkerConnectionAttempt");

    private static readonly EventId
        ConnectionEstablishedEvent =
            new(
                4201,
                "RabbitMqWorkerConnectionEstablished");

    private static readonly EventId
        ConnectionAttemptFailedEvent =
            new(
                4202,
                "RabbitMqWorkerConnectionAttemptFailed");

    private static readonly EventId
        ConnectionShutdownEvent =
            new(
                4203,
                "RabbitMqWorkerConnectionShutdown");

    private static readonly EventId
        ConnectionRecoveryFailedEvent =
            new(
                4204,
                "RabbitMqWorkerConnectionRecoveryFailed");

    private static readonly EventId
        ConnectionRecoverySucceededEvent =
            new(
                4205,
                "RabbitMqWorkerConnectionRecoverySucceeded");

    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly ILogger<
        RabbitMqWorkerConnectionProvider>
        _logger;

    public RabbitMqWorkerConnectionProvider(
        IOptions<RabbitMqOptions> options,
        RabbitMqConnectionFactory
            connectionFactory,
        ILogger<
            RabbitMqWorkerConnectionProvider>
            logger)
    {
        _options =
            options.Value;

        _connectionFactory =
            connectionFactory;

        _logger =
            logger;
    }

    public async Task<IConnection>
        CreateAsync(
            string componentName,
            string clientName,
            CancellationToken cancellationToken =
                default)
    {
        if (string.IsNullOrWhiteSpace(
                componentName))
        {
            throw new ArgumentException(
                "RabbitMQ component name is required.",
                nameof(componentName));
        }

        if (string.IsNullOrWhiteSpace(
                clientName))
        {
            throw new ArgumentException(
                "RabbitMQ client name is required.",
                nameof(clientName));
        }

        var normalizedComponentName =
            componentName.Trim();

        var normalizedClientName =
            clientName.Trim();

        var factory =
            _connectionFactory.Create(
                normalizedClientName,
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
                    "RabbitMQ worker connection attempt. Module: {Module}, Component: {Component}, Client: {Client}, Host: {HostName}, Port: {Port}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    "RabbitMQ",
                    normalizedComponentName,
                    normalizedClientName,
                    _options.HostName,
                    _options.Port,
                    attempt,
                    _options.ConnectionRetryCount);

                var connection =
                    await factory
                        .CreateConnectionAsync(
                            normalizedClientName,
                            cancellationToken);

                SubscribeToConnectionEvents(
                    connection,
                    normalizedComponentName);

                _logger.LogInformation(
                    ConnectionEstablishedEvent,
                    "RabbitMQ worker connection established successfully. Module: {Module}, Component: {Component}, Client: {Client}.",
                    "RabbitMQ",
                    normalizedComponentName,
                    normalizedClientName);

                return connection;
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
                    "RabbitMQ worker connection attempt failed. Module: {Module}, Component: {Component}, Client: {Client}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}, FailureType: {FailureType}.",
                    "RabbitMQ",
                    normalizedComponentName,
                    normalizedClientName,
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
            $"RabbitMQ component '{normalizedComponentName}' "
            + "could not establish a connection after all configured retry attempts.",
            lastException);
    }

    private void SubscribeToConnectionEvents(
        IConnection connection,
        string componentName)
    {
        connection.ConnectionShutdownAsync +=
            (
                sender,
                eventArgs) =>
            {
                _logger.LogWarning(
                    ConnectionShutdownEvent,
                    "RabbitMQ worker connection shut down. Module: {Module}, Component: {Component}, ReplyCode: {ReplyCode}, Reason: {Reason}.",
                    "RabbitMQ",
                    componentName,
                    eventArgs.ReplyCode,
                    eventArgs.ReplyText);

                return Task.CompletedTask;
            };

        connection.ConnectionRecoveryErrorAsync +=
            (
                sender,
                eventArgs) =>
            {
                _logger.LogError(
                    ConnectionRecoveryFailedEvent,
                    eventArgs.Exception,
                    "RabbitMQ worker connection recovery failed. Module: {Module}, Component: {Component}.",
                    "RabbitMQ",
                    componentName);

                return Task.CompletedTask;
            };

        connection.RecoverySucceededAsync +=
            (
                sender,
                eventArgs) =>
            {
                _logger.LogInformation(
                    ConnectionRecoverySucceededEvent,
                    "RabbitMQ worker connection recovery succeeded. Module: {Module}, Component: {Component}.",
                    "RabbitMQ",
                    componentName);

                return Task.CompletedTask;
            };
    }
}