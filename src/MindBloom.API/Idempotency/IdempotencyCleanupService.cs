using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.API.Idempotency;

public sealed class IdempotencyCleanupService
    : BackgroundService
{
    private readonly IServiceScopeFactory
        _scopeFactory;

    private readonly IdempotencyOptions
        _options;

    private readonly ILogger<
        IdempotencyCleanupService>
        _logger;

    public IdempotencyCleanupService(
        IServiceScopeFactory scopeFactory,
        IOptions<IdempotencyOptions> options,
        ILogger<IdempotencyCleanupService>
            logger)
    {
        _scopeFactory =
            scopeFactory;

        _options =
            options.Value;

        _logger =
            logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        while (!stoppingToken
                   .IsCancellationRequested)
        {
            try
            {
                await CleanupAsync(
                    stoppingToken);
            }
            catch (OperationCanceledException)
                when (stoppingToken
                    .IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Idempotency cleanup failed. "
                    + "Module: {Module}.",
                    "Idempotency");
            }

            await Task.Delay(
                TimeSpan.FromMinutes(
                    _options
                        .CleanupIntervalMinutes),
                stoppingToken);
        }
    }

    private async Task CleanupAsync(
        CancellationToken cancellationToken)
    {
        using var scope =
            _scopeFactory.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var now =
            DateTime.UtcNow;

        var deleted =
            await context
                .ApiIdempotencyRecords
                .Where(record =>
                    record.ExpiresAtUtc <=
                        now)
                .ExecuteDeleteAsync(
                    cancellationToken);

        if (deleted > 0)
        {
            _logger.LogInformation(
                "Expired idempotency records "
                + "were removed. "
                + "Module: {Module}, "
                + "DeletedCount: {DeletedCount}.",
                "Idempotency",
                deleted);
        }
    }
}