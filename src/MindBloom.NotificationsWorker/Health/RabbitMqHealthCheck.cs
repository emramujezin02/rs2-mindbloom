using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Health;

public sealed class RabbitMqHealthCheck
    : IHealthCheck
{
    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    private readonly RabbitMqOptions
        _options;

    private readonly ILogger<RabbitMqHealthCheck>
        _logger;

    public RabbitMqHealthCheck(
        RabbitMqConnectionFactory connectionFactory,
        IOptions<RabbitMqOptions> options,
        ILogger<RabbitMqHealthCheck> logger)
    {
        _connectionFactory =
            connectionFactory;

        _options =
            options.Value;

        _logger =
            logger;
    }

    public async Task<HealthCheckResult>
        CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken =
                default)
    {
        IConnection? connection =
            null;

        IChannel? channel =
            null;

        try
        {
            var clientName =
                $"{_options.ConsumerClientName}-health";

            var factory =
                _connectionFactory.Create(
                    clientName,
                    consumerDispatchConcurrency: 1);

            connection =
                await factory
                    .CreateConnectionAsync(
                        clientName,
                        cancellationToken);

            channel =
                await connection
                    .CreateChannelAsync(
                        cancellationToken:
                            cancellationToken);

            if (!connection.IsOpen ||
                !channel.IsOpen)
            {
                return HealthCheckResult
                    .Unhealthy(
                        "RabbitMQ connection or channel is not open.");
            }

            return HealthCheckResult
                .Healthy(
                    "RabbitMQ connection is available.");
        }
        catch (OperationCanceledException)
            when (cancellationToken
                .IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "RabbitMQ health check failed.");

            return HealthCheckResult
                .Unhealthy(
                    "RabbitMQ is unavailable.",
                    exception);
        }
        finally
        {
            if (channel is not null)
            {
                try
                {
                    if (channel.IsOpen)
                    {
                        await channel.CloseAsync(
                            cancellationToken:
                                CancellationToken.None);
                    }
                }
                catch
                {
                }

                await channel.DisposeAsync();
            }

            if (connection is not null)
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
                }

                await connection.DisposeAsync();
            }
        }
    }
}