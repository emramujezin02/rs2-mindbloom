using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Persistence.Migration;

public static class DevelopmentDatabaseMigrator
{
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

        logger.LogInformation(
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
                        "Database is already up to date. "
                        + "No pending EF Core migrations were found.");

                    return;
                }

                logger.LogInformation(
                    "Applying {MigrationCount} pending EF Core migration(s): {Migrations}.",
                    pendingMigrations.Count,
                    string.Join(
                        ", ",
                        pendingMigrations));

                await context.Database
                    .MigrateAsync(
                        cancellationToken);

                logger.LogInformation(
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
                "Development database migration was cancelled.");

            throw;
        }
        catch (Exception exception)
        {
            logger.LogCritical(
                exception,
                "Development database migration failed. "
                + "Application startup will be stopped.");

            throw new InvalidOperationException(
                "Development database migration failed. "
                + "Application startup cannot continue. "
                + "See the preceding database migration log for details.",
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
                    "Checking database availability. "
                    + "Attempt {Attempt}/{MaximumAttempts}.",
                    attempt,
                    maximumAttempts);

                if (await context.Database
                        .CanConnectAsync(
                            cancellationToken))
                {
                    logger.LogInformation(
                        "Database connection is available.");

                    return;
                }

                logger.LogWarning(
                    "Database is not available yet. "
                    + "Attempt {Attempt}/{MaximumAttempts}.",
                    attempt,
                    maximumAttempts);
            }
            catch (Exception exception)
            {
                lastException =
                    exception;

                logger.LogWarning(
                    exception,
                    "Database connection attempt "
                    + "{Attempt}/{MaximumAttempts} failed.",
                    attempt,
                    maximumAttempts);
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
            "SQL Server migration lock acquired successfully.");
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
                "SQL Server migration lock released.");
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                exception,
                "Failed to explicitly release the "
                + "SQL Server migration lock. "
                + "The lock will be released when "
                + "the database connection closes.");
        }
    }
}