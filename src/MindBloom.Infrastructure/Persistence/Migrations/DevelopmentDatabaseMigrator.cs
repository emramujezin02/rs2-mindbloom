using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Persistence.Migration;

public static class DevelopmentDatabaseMigrator
{
    private static readonly EventId
    MigrationStartedEvent =
        new(
            3300,
            "DatabaseMigrationStarted");

    private static readonly EventId
        DatabaseUpToDateEvent =
            new(
                3301,
                "DatabaseAlreadyUpToDate");

    private static readonly EventId
        PendingMigrationsEvent =
            new(
                3302,
                "PendingDatabaseMigrations");

    private static readonly EventId
        MigrationCompletedEvent =
            new(
                3303,
                "DatabaseMigrationCompleted");

    private static readonly EventId
        MigrationCancelledEvent =
            new(
                3304,
                "DatabaseMigrationCancelled");

    private static readonly EventId
        MigrationFailedEvent =
            new(
                3305,
                "DatabaseMigrationFailed");

    private static readonly EventId
        DatabaseAvailabilityCheckEvent =
            new(
                3310,
                "DatabaseAvailabilityCheck");

    private static readonly EventId
        DatabaseAvailableEvent =
            new(
                3311,
                "DatabaseAvailable");

    private static readonly EventId
        DatabaseUnavailableEvent =
            new(
                3312,
                "DatabaseUnavailable");

    private static readonly EventId
        DatabaseConnectionAttemptFailedEvent =
            new(
                3313,
                "DatabaseConnectionAttemptFailed");

    private static readonly EventId
        MigrationLockAcquiredEvent =
            new(
                3320,
                "DatabaseMigrationLockAcquired");

    private static readonly EventId
        MigrationLockReleasedEvent =
            new(
                3321,
                "DatabaseMigrationLockReleased");

    private static readonly EventId
        MigrationLockReleaseFailedEvent =
            new(
                3322,
                "DatabaseMigrationLockReleaseFailed");

    private const string MigrationLockResource =
        "MindBloom.DatabaseMigration";

    private const int MigrationLockTimeoutMilliseconds =
        60000;

    public static async Task MigrateAsync(
        IServiceProvider serviceProvider,
        CancellationToken cancellationToken = default)
    {
        using var scope =
            serviceProvider.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var logger =
            scope.ServiceProvider
                .GetRequiredService<
                    ILogger<ApplicationDbContext>>();

        var environment =
            scope.ServiceProvider
                .GetRequiredService<
                    IHostEnvironment>();

        using var logScope =
            logger.BeginScope(
                new Dictionary<string, object?>
                {
                    ["Module"] =
                        "DatabaseMigration",

                    ["Environment"] =
                        environment.EnvironmentName
                });

        logger.LogInformation(
            MigrationStartedEvent,
            "Development database migration startup process started.");

        try
        {
            await WaitForDatabaseAsync(
                context,
                logger,
                cancellationToken);

            await context.Database
                .OpenConnectionAsync(
                    cancellationToken);

            var lockAcquired = false;

            try
            {
                await AcquireMigrationLockAsync(
                    context,
                    logger,
                    cancellationToken);

                lockAcquired = true;

                var pendingMigrations =
                    (await context.Database
                        .GetPendingMigrationsAsync(
                            cancellationToken))
                    .ToList();

                if (pendingMigrations.Count == 0)
                {
                    logger.LogInformation(
                        DatabaseUpToDateEvent,
                        "Database is already up to date. No pending EF Core migrations were found.");

                    return;
                }

                logger.LogInformation(
                    PendingMigrationsEvent,
                    "Applying pending EF Core migrations. MigrationCount: {MigrationCount}, Migrations: {Migrations}.",
                    pendingMigrations.Count,
                    string.Join(
                        ", ",
                        pendingMigrations));

                await context.Database
                    .MigrateAsync(
                        cancellationToken);

                logger.LogInformation(
    MigrationCompletedEvent,
    "Development database migrations completed successfully.");
            }
            finally
            {
                if (lockAcquired)
                {
                    await ReleaseMigrationLockAsync(
                        context,
                        logger,
                        cancellationToken);
                }

                await context.Database
                    .CloseConnectionAsync();
            }
        }
        catch (OperationCanceledException)
            when (cancellationToken
                .IsCancellationRequested)
        {
            logger.LogWarning(
                MigrationCancelledEvent,
                "Development database migration was cancelled.");

            throw;
        }
        catch (Exception exception)
        {
            logger.LogCritical(
                MigrationFailedEvent,
                "Development database migration failed. Application startup will be stopped. FailureType: {FailureType}.",
                exception.GetType().Name);

            throw new InvalidOperationException(
                "Development database migration failed. "
                + "Application startup cannot continue.",
                exception);
        }
    }

    private static async Task WaitForDatabaseAsync(
        ApplicationDbContext context,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        const int maximumAttempts = 10;

        var delay =
            TimeSpan.FromSeconds(3);

        Exception? lastException =
            null;

        for (var attempt = 1;
             attempt <= maximumAttempts;
             attempt++)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            try
            {
                logger.LogInformation(
                    DatabaseAvailabilityCheckEvent,
                    "Checking database availability. Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    attempt,
                    maximumAttempts);

                if (await context.Database
                        .CanConnectAsync(
                            cancellationToken))
                {
                    logger.LogInformation(
                        DatabaseAvailableEvent,
                        "Database connection is available.");

                    return;
                }

                logger.LogWarning(
                    DatabaseUnavailableEvent,
                    "Database is not available yet. Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    attempt,
                    maximumAttempts);
            }
            catch (Exception exception)
            {
                lastException =
                    exception;

                logger.LogWarning(
                    DatabaseConnectionAttemptFailedEvent,
                    "Database connection attempt failed. Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}, FailureType: {FailureType}.",
                    attempt,
                    maximumAttempts,
                    exception.GetType().Name);
            }

            if (attempt <
                maximumAttempts)
            {
                await Task.Delay(
                    delay,
                    cancellationToken);
            }
        }

        throw new InvalidOperationException(
            $"Database was not available after "
            + $"{maximumAttempts} startup attempts.",
            lastException);
    }

    private static async Task
        AcquireMigrationLockAsync(
            ApplicationDbContext context,
            ILogger logger,
            CancellationToken cancellationToken)
    {
        await using var command =
            context.Database
                .GetDbConnection()
                .CreateCommand();

        command.CommandText =
            """
            DECLARE @result int;

            EXEC @result = sp_getapplock
                @Resource = @resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Session',
                @LockTimeout = @timeout;

            SELECT @result;
            """;

        var resourceParameter =
            command.CreateParameter();

        resourceParameter.ParameterName =
            "@resource";

        resourceParameter.DbType =
            DbType.String;

        resourceParameter.Value =
            MigrationLockResource;

        command.Parameters.Add(
            resourceParameter);

        var timeoutParameter =
            command.CreateParameter();

        timeoutParameter.ParameterName =
            "@timeout";

        timeoutParameter.DbType =
            DbType.Int32;

        timeoutParameter.Value =
            MigrationLockTimeoutMilliseconds;

        command.Parameters.Add(
            timeoutParameter);

        var result =
            await command.ExecuteScalarAsync(
                cancellationToken);

        if (result is null ||
            !int.TryParse(
                result.ToString(),
                out var lockResult) ||
            lockResult < 0)
        {
            throw new InvalidOperationException(
                "Could not acquire the SQL Server "
                + "database migration lock.");
        }

        logger.LogInformation(
            MigrationLockAcquiredEvent,
            "SQL Server migration lock acquired successfully. LockResource: {LockResource}.",
            MigrationLockResource);
    }

    private static async Task
        ReleaseMigrationLockAsync(
            ApplicationDbContext context,
            ILogger logger,
            CancellationToken cancellationToken)
    {
        try
        {
            await using var command =
                context.Database
                    .GetDbConnection()
                    .CreateCommand();

            command.CommandText =
                """
                EXEC sp_releaseapplock
                    @Resource = @resource,
                    @LockOwner = 'Session';
                """;

            var resourceParameter =
                command.CreateParameter();

            resourceParameter.ParameterName =
                "@resource";

            resourceParameter.DbType =
                DbType.String;

            resourceParameter.Value =
                MigrationLockResource;

            command.Parameters.Add(
                resourceParameter);

            await command.ExecuteNonQueryAsync(
                cancellationToken);

            logger.LogInformation(
                MigrationLockReleasedEvent,
                "SQL Server migration lock released. LockResource: {LockResource}.",
                MigrationLockResource);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                MigrationLockReleaseFailedEvent,
                exception,
                "Failed to explicitly release the SQL Server migration lock. The lock will be released when the database connection closes. LockResource: {LockResource}.",
                MigrationLockResource);
        }
    }
}