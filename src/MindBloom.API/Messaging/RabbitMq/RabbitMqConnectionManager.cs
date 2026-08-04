using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace MindBloom.API.Messaging.RabbitMq;

public sealed class RabbitMqConnectionManager
    : IAsyncDisposable
{
    private readonly RabbitMqOptions
        _options;

    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly ILogger<RabbitMqConnectionManager>
        _logger;

    private readonly SemaphoreSlim
        _connectionLock =
            new(1, 1);

    private IConnection? _connection;

    private bool _disposed;

    public RabbitMqConnectionManager(
        IOptions<RabbitMqOptions> options,
        RabbitMqConnectionFactory connectionFactory,
        ILogger<RabbitMqConnectionManager> logger)
    {
        _options =
            options.Value;

        _connectionFactory =
            connectionFactory;

        _logger =
            logger;
    }

    public async Task<IConnection>
        GetConnectionAsync(
            CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(
            _disposed,
            nameof(RabbitMqConnectionManager));

        if (_connection is { IsOpen: true })
        {
            return _connection;
        }

        await _connectionLock.WaitAsync(
            cancellationToken);

        try
        {
            if (_connection is { IsOpen: true })
            {
                return _connection;
            }

            if (_connection is not null)
            {
                await DisposeConnectionAsync(
                    _connection);

                _connection = null;
            }

            _connection =
                await CreateConnectionWithRetryAsync(
                    cancellationToken);

            SubscribeToConnectionEvents(
                _connection);

            return _connection;
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    private async Task<IConnection>
        CreateConnectionWithRetryAsync(
            CancellationToken cancellationToken)
    {
        var factory =
            _connectionFactory.Create(
                _options.PublisherClientName);

        Exception? lastException = null;

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
                    "Connecting API publisher to RabbitMQ at {HostName}:{Port}. Attempt {Attempt}/{MaximumAttempts}.",
                    _options.HostName,
                    _options.Port,
                    attempt,
                    _options.ConnectionRetryCount);

                var connection =
                    await factory.CreateConnectionAsync(
                        _options
                            .PublisherClientName,
                        cancellationToken);

                _logger.LogInformation(
                    "RabbitMQ API publisher connection established successfully.");

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
                    "RabbitMQ connection attempt {Attempt}/{MaximumAttempts} failed.",
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
            "RabbitMQ connection could not be established after all configured retry attempts.",
            lastException);
    }

    private void SubscribeToConnectionEvents(
        IConnection connection)
    {
        connection.ConnectionShutdownAsync +=
            OnConnectionShutdownAsync;

        connection.ConnectionRecoveryErrorAsync +=
            OnConnectionRecoveryErrorAsync;

        connection.RecoverySucceededAsync +=
            OnRecoverySucceededAsync;
    }

    private Task OnConnectionShutdownAsync(
        object sender,
        ShutdownEventArgs eventArgs)
    {
        _logger.LogWarning(
            "RabbitMQ connection was shut down. Reply code: {ReplyCode}. Reason: {Reason}.",
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
            "RabbitMQ automatic connection recovery failed.");

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

    private static async Task
        DisposeConnectionAsync(
            IConnection connection)
    {
        try
        {
            if (connection.IsOpen)
            {
                await connection.CloseAsync(
                    cancellationToken:
                        CancellationToken.None);
            }
        }
        catch
        {
            // Dispose must still be attempted.
        }

        await connection.DisposeAsync();
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;

        await _connectionLock.WaitAsync();

        try
        {
            if (_connection is not null)
            {
                await DisposeConnectionAsync(
                    _connection);

                _connection = null;
            }
        }
        finally
        {
            _connectionLock.Release();

            _connectionLock.Dispose();
        }
    }
}