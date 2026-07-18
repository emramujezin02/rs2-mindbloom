using Microsoft.Extensions.Options;
using MindBloom.API.Messaging.Configuration;
using RabbitMQ.Client;

namespace MindBloom.API.Messaging.RabbitMq;

/// <summary>
/// Manages one long-lived RabbitMQ connection for the entire API process.
/// Registered as a singleton.
/// </summary>
public sealed class RabbitMqConnectionManager : IAsyncDisposable
{
    private readonly RabbitMqOptions _options;
    private readonly ILogger<RabbitMqConnectionManager> _logger;

    private readonly SemaphoreSlim _connectionLock = new(1, 1);

    private IConnection? _connection;
    private bool _disposed;

    public RabbitMqConnectionManager(
        IOptions<RabbitMqOptions> options,
        ILogger<RabbitMqConnectionManager> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public async Task<IConnection> GetConnectionAsync(
        CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(
            _disposed,
            nameof(RabbitMqConnectionManager));

        if (_connection is { IsOpen: true })
        {
            return _connection;
        }

        await _connectionLock.WaitAsync(cancellationToken);

        try
        {
            if (_connection is { IsOpen: true })
            {
                return _connection;
            }

            if (_connection is not null)
            {
                await DisposeConnectionAsync(_connection);
                _connection = null;
            }

            var factory = new ConnectionFactory
            {
                HostName = _options.HostName,
                Port = _options.Port,
                UserName = _options.UserName,
                Password = _options.Password,
                VirtualHost = _options.VirtualHost,

                AutomaticRecoveryEnabled =
                    _options.AutomaticRecoveryEnabled,

                TopologyRecoveryEnabled = true,

                NetworkRecoveryInterval = TimeSpan.FromSeconds(
                    _options.NetworkRecoveryIntervalSeconds),

                RequestedHeartbeat = TimeSpan.FromSeconds(
                    _options.RequestedHeartbeatSeconds),

                ClientProvidedName =
                    _options.ClientProvidedName
            };

            _logger.LogInformation(
                "Connecting to RabbitMQ at {HostName}:{Port}, virtual host {VirtualHost}.",
                _options.HostName,
                _options.Port,
                _options.VirtualHost);

            _connection = await factory.CreateConnectionAsync(
                _options.ClientProvidedName,
                cancellationToken);

            _connection.ConnectionShutdownAsync += OnConnectionShutdownAsync;

            _connection.ConnectionRecoveryErrorAsync +=
                OnConnectionRecoveryErrorAsync;

            _connection.RecoverySucceededAsync +=
                OnRecoverySucceededAsync;

            _logger.LogInformation(
                "RabbitMQ connection established successfully.");

            return _connection;
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "RabbitMQ connection could not be established.");

            throw;
        }
        finally
        {
            _connectionLock.Release();
        }
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

    private static async Task DisposeConnectionAsync(
        IConnection connection)
    {
        try
        {
            if (connection.IsOpen)
            {
                await connection.CloseAsync(
                    cancellationToken: CancellationToken.None);
            }
        }
        catch
        {
            // Dispose still needs to be attempted.
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
                await DisposeConnectionAsync(_connection);
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