using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;

namespace MindBloom.UnitTests.Authentication;

// Fault-injecting lifecycle fakes and InMemory only. These are NOT SQL lock tests.
public sealed class AuthSessionWriteGuardTests
{
    [Fact]
    public async Task Successful_attempt_locks_commits_and_disposes_once()
    {
        var tx = new FakeTransaction();
        var value = await Run(tx, () => Task.FromResult(42));
        Assert.Equal(42, value);
        Assert.Equal(new[] { "lock:72", "commit", "dispose" }, tx.Events);
    }

    [Fact]
    public async Task Arbitrary_unauthorized_exception_rolls_back_instead_of_committing()
    {
        var tx = new FakeTransaction();
        var expected = new UnauthorizedAccessException("synthetic unexpected failure");
        var actual = await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            Run<int>(tx, () => Task.FromException<int>(expected)));
        Assert.Same(expected, actual);
        Assert.Equal(new[] { "lock:72", "rollback", "dispose" }, tx.Events);
    }

    [Fact]
    public async Task Expected_refresh_rejection_is_committed_data_then_rethrown_after_commit()
    {
        var tx = new FakeTransaction();
        var result = await Run(tx, () => Task.FromResult(AuthRefreshOutcome.Rejected(AuthRefreshRejection.Reused)));
        Assert.Equal(new[] { "lock:72", "commit", "dispose" }, tx.Events);
        var rejection = Assert.Throws<UnauthorizedAccessException>(() => result.GetResponse());
        Assert.Equal("Refresh token reuse detected.", rejection.Message);
    }

    [Fact]
    public async Task Lost_commit_acknowledgement_is_uncertain_and_operation_is_not_replayed()
    {
        var tx = new FakeTransaction { CommitFailure = new IOException("synthetic lost acknowledgement") };
        var attempts = 0;
        var error = await Assert.ThrowsAsync<AuthSessionCommitUncertainException>(() => Run(tx, () =>
        {
            attempts++;
            return Task.FromResult("synthetic-result");
        }));
        Assert.Equal(1, attempts);
        Assert.True(tx.CommitReached);
        Assert.Same(tx.CommitFailure, error.InnerException);
        Assert.Equal(1, tx.Events.Count(x => x == "commit"));
    }

    [Fact]
    public async Task Rollback_and_dispose_failures_preserve_original_exception_and_diagnostics()
    {
        var tx = new FakeTransaction { RollbackFailure = new IOException(), DisposeFailure = new IOException() };
        var primary = new InvalidOperationException("synthetic operation failure");
        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Run<int>(tx, () => Task.FromException<int>(primary)));
        Assert.Same(primary, error);
        Assert.Equal(nameof(IOException), error.Data["AuthSession.RollbackFailure"]);
        Assert.Equal(nameof(IOException), error.Data["AuthSession.DisposeFailure"]);
        Assert.DoesNotContain("commit", tx.Events);
    }

    [Fact]
    public async Task Cleanup_failure_after_confirmed_commit_is_explicit_and_not_rolled_back()
    {
        var tx = new FakeTransaction { DisposeFailure = new IOException() };
        var error = await Assert.ThrowsAsync<AuthSessionCleanupException>(() => Run(tx, () => Task.FromResult(1)));
        Assert.True(error.CommitConfirmed);
        Assert.DoesNotContain("rollback", tx.Events);
    }

    [Fact]
    public async Task Lock_failure_prevents_action_and_releases_transaction()
    {
        var tx = new FakeTransaction { LockFailure = new TimeoutException() };
        var called = false;
        await Assert.ThrowsAsync<TimeoutException>(() => Run(tx, () => { called = true; return Task.FromResult(1); }));
        Assert.False(called);
        Assert.Equal(new[] { "lock:72", "rollback", "dispose" }, tx.Events);
    }

    [Fact]
    public async Task Begin_failure_does_not_execute_action()
    {
        var called = false;
        await Assert.ThrowsAsync<IOException>(() => AuthSessionWriteGuard.ExecuteAttemptAsync(
            () => Task.FromException<IAuthSessionTransaction>(new IOException()), 72,
            () => { called = true; return Task.FromResult(1); }));
        Assert.False(called);
    }

    [Fact]
    public async Task Pending_changes_are_rejected_and_preserved()
    {
        await using var db = NewDb();
        var user = new ApplicationUser { Id = 72, UserName = "synthetic", FirstName = "Synthetic", LastName = "Guard" };
        db.Users.Add(user);
        var called = false;
        await Assert.ThrowsAsync<InvalidOperationException>(() => AuthSessionWriteGuard.ExecuteAsync(db, 72,
            () => { called = true; return Task.FromResult(1); }));
        Assert.False(called);
        Assert.Equal(EntityState.Added, db.Entry(user).State);
        Assert.Equal("synthetic", user.UserName);
    }

    [Fact]
    public async Task Unchanged_unrelated_tracking_is_retained()
    {
        await using var db = NewDb();
        var user = new ApplicationUser { Id = 72, UserName = "synthetic", FirstName = "Synthetic", LastName = "Guard" };
        db.Users.Add(user); await db.SaveChangesAsync();
        await AuthSessionWriteGuard.ExecuteAsync(db, 72, () => Task.FromResult(1));
        Assert.Same(user, Assert.Single(db.ChangeTracker.Entries<ApplicationUser>()).Entity);
    }

    [Fact]
    public async Task Failed_context_is_not_reused_for_another_auth_write()
    {
        await using var db = NewDb();
        await Assert.ThrowsAsync<IOException>(() => AuthSessionWriteGuard.ExecuteAsync<int>(db, 72,
            () => Task.FromException<int>(new IOException())));
        var called = false;
        await Assert.ThrowsAsync<InvalidOperationException>(() => AuthSessionWriteGuard.ExecuteAsync(db, 72,
            () => { called = true; return Task.FromResult(1); }));
        Assert.False(called);
    }

    [Fact]
    public async Task Single_attempt_strategy_suppresses_nested_provider_style_retry()
    {
        await using var db = NewDb();
        var attempts = 0;
        await Assert.ThrowsAsync<SyntheticTransientException>(() => new AuthSingleAttemptExecutionStrategy(db).ExecuteAsync(
            () => new RetryingStrategy(db).ExecuteAsync(() =>
            {
                attempts++;
                return Task.FromException<int>(new SyntheticTransientException());
            })));
        Assert.Equal(1, attempts);
        Assert.Null(ExecutionStrategy.Current);
    }

    [Fact]
    public async Task Outer_retry_strategy_is_rejected_before_auth_action()
    {
        await using var db = NewDb();
        var called = false;
        await Assert.ThrowsAsync<InvalidOperationException>(() => new RetryingStrategy(db).ExecuteAsync(
            () => AuthSessionWriteGuard.ExecuteAsync(db, 72,
                () => { called = true; return Task.FromResult(1); })));
        Assert.False(called);
    }

    [Fact]
    public async Task Invalid_outcome_cannot_be_constructed()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => AuthRefreshOutcome.Rejected((AuthRefreshRejection)999));
        Assert.Throws<ArgumentNullException>(() => AuthRefreshOutcome.Accepted(null!));
        await Task.CompletedTask;
    }

    [Fact]
    public async Task Cleanup_logging_failure_does_not_replace_primary_failure()
    {
        var tx = new FakeTransaction { RollbackFailure = new IOException() };
        var primary = new InvalidOperationException("synthetic primary failure");
        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            AuthSessionWriteGuard.ExecuteAttemptAsync(() => Task.FromResult<IAuthSessionTransaction>(tx), 72,
                () => Task.FromException<int>(primary), (_, _) => throw new IOException()));
        Assert.Same(primary, error);
        Assert.Equal(nameof(IOException), error.Data["AuthSession.CleanupLoggingFailure"]);
    }

    [Fact]
    public async Task Ambient_transaction_is_rejected_without_executing_auth_action()
    {
        await using var db = NewDb();
        using var scope = new System.Transactions.TransactionScope(System.Transactions.TransactionScopeAsyncFlowOption.Enabled);
        var called = false;
        await Assert.ThrowsAsync<InvalidOperationException>(() => AuthSessionWriteGuard.ExecuteAsync(db, 72,
            () => { called = true; return Task.FromResult(1); }));
        Assert.False(called);
    }
    [Fact]
    public async Task Disabled_auto_detection_cannot_hide_pending_changes()
    {
        await using var db = NewDb();
        var user = new ApplicationUser { Id = 72, UserName = "synthetic", FirstName = "before", LastName = "Guard" };
        db.Users.Add(user); await db.SaveChangesAsync();
        db.ChangeTracker.AutoDetectChangesEnabled = false;
        user.FirstName = "after";
        await Assert.ThrowsAsync<InvalidOperationException>(() => AuthSessionWriteGuard.ExecuteAsync(db, 72, () => Task.FromResult(1)));
        Assert.Equal(EntityState.Modified, db.Entry(user).State);
        Assert.Equal("after", user.FirstName);
    }

    [Fact]
    public async Task Rejection_with_unconfirmed_commit_is_technical_failure_not_confirmed_rejection()
    {
        var tx = new FakeTransaction { CommitFailure = new IOException() };
        await Assert.ThrowsAsync<AuthSessionCommitUncertainException>(() => Run(tx,
            () => Task.FromResult(AuthRefreshOutcome.Rejected(AuthRefreshRejection.Expired))));
    }
    private static ApplicationDbContext NewDb() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase($"auth-guard-unit-{Guid.NewGuid():N}").Options);
    private static Task<T> Run<T>(FakeTransaction transaction, Func<Task<T>> action) =>
        AuthSessionWriteGuard.ExecuteAttemptAsync(() => Task.FromResult<IAuthSessionTransaction>(transaction), 72, action);
    private sealed class SyntheticTransientException : Exception { }
    private sealed class RetryingStrategy(DbContext context) : ExecutionStrategy(context, 3, TimeSpan.Zero)
    {
        protected override bool ShouldRetryOn(Exception exception) => exception is SyntheticTransientException;
    }
    private sealed class FakeTransaction : IAuthSessionTransaction
    {
        public List<string> Events { get; } = [];
        public Exception? LockFailure { get; init; }
        public Exception? CommitFailure { get; init; }
        public Exception? RollbackFailure { get; init; }
        public Exception? DisposeFailure { get; init; }
        public bool CommitReached { get; private set; }
        public Task AcquireLockAsync(int userId) { Events.Add($"lock:{userId}"); return LockFailure == null ? Task.CompletedTask : Task.FromException(LockFailure); }
        public Task CommitAsync() { Events.Add("commit"); CommitReached = true; return CommitFailure == null ? Task.CompletedTask : Task.FromException(CommitFailure); }
        public Task RollbackAsync() { Events.Add("rollback"); return RollbackFailure == null ? Task.CompletedTask : Task.FromException(RollbackFailure); }
        public ValueTask DisposeAsync() { Events.Add("dispose"); return DisposeFailure == null ? ValueTask.CompletedTask : ValueTask.FromException(DisposeFailure); }
    }
}
