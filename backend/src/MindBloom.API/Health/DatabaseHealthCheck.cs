using Microsoft.Extensions.Diagnostics.HealthChecks;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.API.Health;

public sealed class DatabaseHealthCheck
    : IHealthCheck
{
    private readonly ApplicationDbContext
        _context;

    public DatabaseHealthCheck(
        ApplicationDbContext context)
    {
        _context =
            context;
    }

    public async Task<HealthCheckResult>
        CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken =
                default)
    {
        try
        {
            var canConnect =
                await _context.Database
                    .CanConnectAsync(
                        cancellationToken);

            return canConnect
                ? HealthCheckResult.Healthy(
                    "SQL Server is reachable.")
                : HealthCheckResult.Unhealthy(
                    "SQL Server is not reachable.");
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy(
                "SQL Server health check failed.",
                exception);
        }
    }
}