using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace MindBloom.NotificationsWorker.Messaging;

public sealed class RabbitMqWorkerConnectionProvider
{
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
                    "RabbitMQ component {Component} is connecting to {HostName}:{Port}. "
                    + "Attempt {Attempt}/{MaximumAttempts}.",
                    normalizedComponentName,
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
                    "RabbitMQ connection established successfully. "
                    + "Component: {Component}, client: {ClientName}.",
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
                    exception,
                    "RabbitMQ connection attempt failed. "
                    + "Component: {Component}, "
                    + "attempt: {Attempt}/{MaximumAttempts}.",
                    normalizedComponentName,
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
                    "RabbitMQ connection shut down. "
                    + "Component: {Component}, "
                    + "reply code: {ReplyCode}, "
                    + "reason: {Reason}.",
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
                    eventArgs.Exception,
                    "RabbitMQ connection recovery failed. "
                    + "Component: {Component}.",
                    componentName);

                return Task.CompletedTask;
            };

        connection.RecoverySucceededAsync +=
            (
                sender,
                eventArgs) =>
            {
                _logger.LogInformation(
                    "RabbitMQ connection recovery succeeded. "
                    + "Component: {Component}.",
                    componentName);

                return Task.CompletedTask;
            };
    }
}