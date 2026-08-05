using System.Net.Sockets;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace MindBloom.NotificationsWorker.Health;

public sealed class EmailProviderHealthCheck
    : IHealthCheck
{
    private readonly ILogger<
        EmailProviderHealthCheck>
        _logger;

    public EmailProviderHealthCheck(
        ILogger<EmailProviderHealthCheck>
            logger)
    {
        _logger =
            logger;
    }

    public async Task<HealthCheckResult>
        CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken =
                default)
    {
        var username =
            Environment.GetEnvironmentVariable(
                "EMAIL_USERNAME");

        var password =
            Environment.GetEnvironmentVariable(
                "EMAIL_PASSWORD");

        if (string.IsNullOrWhiteSpace(
                username))
        {
            return HealthCheckResult
                .Unhealthy(
                    "EMAIL_USERNAME is not configured.");
        }

        if (string.IsNullOrWhiteSpace(
                password))
        {
            return HealthCheckResult
                .Unhealthy(
                    "EMAIL_PASSWORD is not configured.");
        }

        try
        {
            using var client =
                new TcpClient();

            await client.ConnectAsync(
                "smtp.gmail.com",
                587,
                cancellationToken);

            if (!client.Connected)
            {
                return HealthCheckResult
                    .Unhealthy(
                        "Email provider connection could not be established.");
            }

            return HealthCheckResult
                .Healthy(
                    "Email provider is reachable.");
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
                "Email provider health check failed.");

            return HealthCheckResult
                .Unhealthy(
                    "Email provider is unavailable.",
                    exception);
        }
    }
}