using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Transactions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Logging;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Security;

internal static class AuthSessionWriteGuard
{
    private static readonly ConditionalWeakTable<ApplicationDbContext, object> FailedContexts = new();

    public static async Task<T> ExecuteAsync<T>(ApplicationDbContext db, int userId, Func<Task<T>> action)
    {
        if (userId <= 0) throw new ArgumentOutOfRangeException(nameof(userId));
        if (FailedContexts.TryGetValue(db, out _))
            throw new InvalidOperationException("Discard the auth context after a failed transaction.");
        db.ChangeTracker.DetectChanges();
        if (db.ChangeTracker.HasChanges())
            throw new InvalidOperationException("Auth operations require a context without pending changes.");
        if (ExecutionStrategy.Current != null || Transaction.Current != null || db.Database.CurrentTransaction != null)
            throw new InvalidOperationException("Auth writes cannot run inside an outer transaction or execution strategy.");
        if (db.Database.ProviderName != "Microsoft.EntityFrameworkCore.InMemory" && !db.Database.IsSqlServer())
            throw new InvalidOperationException("Unsupported auth session provider.");
        try
        {
            return await new AuthSingleAttemptExecutionStrategy(db).ExecuteAsync(async () =>
            {
                // InMemory exercises orchestration only, never SQL transactions.
                if (db.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory") return await action();
                return await ExecuteAttemptAsync(
                    async () => new SqlTransaction(db, await db.Database.BeginTransactionAsync()),
                    userId, action, (phase, error) => db.GetService<ILoggerFactory>()
                        .CreateLogger("MindBloom.AuthSessionWriteGuard")
                        .LogError("Auth session {Phase} cleanup failed ({ExceptionType}).", phase, error.GetType().Name));
            });
        }
        catch
        {
            FailedContexts.GetValue(db, _ => new object());
            throw;
        }
    }

    // Shared transaction lifecycle, tested with fault-injecting fakes. Tests of
    // this lifecycle do not prove SQL Server locking or transaction semantics.
    internal static async Task<T> ExecuteAttemptAsync<T>(Func<Task<IAuthSessionTransaction>> begin,
        int userId, Func<Task<T>> action, Action<string, Exception>? reportCleanup = null)
    {
        IAuthSessionTransaction? transaction = null;
        Exception? primary = null;
        var committed = false;
        try
        {
            transaction = await begin();
            await transaction.AcquireLockAsync(userId);
            var result = await action();
            try { await transaction.CommitAsync(); }
            catch (Exception exception) { throw new AuthSessionCommitUncertainException(exception); }
            committed = true;
            return result;
        }
        catch (Exception exception)
        {
            primary = exception;
            if (transaction != null && !committed)
            {
                try { await transaction.RollbackAsync(); }
                catch (Exception cleanup) { RecordCleanup(primary, "Rollback", cleanup, reportCleanup); }
            }
            throw;
        }
        finally
        {
            if (transaction != null)
            {
                try { await transaction.DisposeAsync(); }
                catch (Exception cleanup)
                {
                    if (primary != null) RecordCleanup(primary, "Dispose", cleanup, reportCleanup);
                    else throw new AuthSessionCleanupException(committed, cleanup);
                }
            }
        }
    }

    private static void RecordCleanup(Exception primary, string phase, Exception cleanup, Action<string, Exception>? reportCleanup)
    {
        primary.Data[$"AuthSession.{phase}Failure"] = cleanup.GetType().Name;
        try { reportCleanup?.Invoke(phase, cleanup); }
        catch (Exception loggingFailure) { primary.Data["AuthSession.CleanupLoggingFailure"] = loggingFailure.GetType().Name; }
        // Never include tokens, command arguments or connection strings.
        try { Trace.TraceError("Auth session {0} cleanup failed ({1}).", phase, cleanup.GetType().Name); }
        catch (Exception traceFailure) { primary.Data["AuthSession.CleanupTraceFailure"] = traceFailure.GetType().Name; }
    }

    private sealed class SqlTransaction(ApplicationDbContext db, IDbContextTransaction transaction)
        : IAuthSessionTransaction
    {
        public Task AcquireLockAsync(int userId)
        {
            var resource = $"MindBloom.AuthSession.{userId}";
            return db.Database.ExecuteSqlInterpolatedAsync($"""
                DECLARE @result int;
                EXEC @result = sys.sp_getapplock @Resource={resource},
                    @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
                IF @result < 0 THROW 51000, 'Auth session lock unavailable.', 1;
                """);
        }
        public Task CommitAsync() => transaction.CommitAsync();
        public Task RollbackAsync() => transaction.RollbackAsync();
        public ValueTask DisposeAsync() => transaction.DisposeAsync();
    }
}

internal interface IAuthSessionTransaction : IAsyncDisposable
{
    Task AcquireLockAsync(int userId);
    Task CommitAsync();
    Task RollbackAsync();
}

// Unlike NonRetryingExecutionStrategy, this ExecutionStrategy base establishes
// Current, suppressing nested provider retries for every command in the unit.
internal sealed class AuthSingleAttemptExecutionStrategy(DbContext context)
    : ExecutionStrategy(context, 0, TimeSpan.Zero)
{
    protected override bool ShouldRetryOn(Exception exception) => false;
}

internal sealed class AuthSessionCommitUncertainException(Exception inner)
    : InvalidOperationException("Auth transaction commit outcome is uncertain. Do not replay this operation automatically.", inner) { }

internal sealed class AuthSessionCleanupException(bool committed, Exception inner)
    : InvalidOperationException("Auth transaction cleanup failed.", inner)
{
    public bool CommitConfirmed { get; } = committed;
}

internal sealed class AuthSessionAuditException(Exception inner)
    : InvalidOperationException("Session revocation was committed, but its audit could not be recorded.", inner) { }
