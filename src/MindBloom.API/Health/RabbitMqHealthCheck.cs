using Microsoft.Extensions.Diagnostics.HealthChecks;
using MindBloom.Infrastructure
    .Messaging.RabbitMq;

namespace MindBloom.API.Health;

public sealed class RabbitMqHealthCheck
    : IHealthCheck
{
    private readonly RabbitMqConnectionFactory
        _connectionFactory;

    public RabbitMqHealthCheck(
        RabbitMqConnectionFactory
            connectionFactory)
    {
        _connectionFactory =
            connectionFactory;
    }

    public async Task<HealthCheckResult>
        CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken =
                default)
    {
        try
        {
            var factory =
                _connectionFactory.Create(
                    "mindbloom-api-health-check");

            await using var connection =
                await factory
                    .CreateConnectionAsync(
                        "mindbloom-api-health-check",
                        cancellationToken);

            if (!connection.IsOpen)
            {
                return HealthCheckResult
                    .Unhealthy(
                        "RabbitMQ connection is not open.");
            }

            return HealthCheckResult.Healthy(
                "RabbitMQ is reachable.");
        }
        catch (OperationCanceledException)
            when (cancellationToken
                .IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy(
                "RabbitMQ health check failed.",
                exception);
        }
    }
}