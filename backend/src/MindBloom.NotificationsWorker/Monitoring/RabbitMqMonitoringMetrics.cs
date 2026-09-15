namespace MindBloom.NotificationsWorker.Monitoring;

public sealed class RabbitMqMonitoringMetrics
{
    private long _successfulMessages;

    private long _retryCount;

    private long _failedMessages;

    public long SuccessfulMessages =>
        Interlocked.Read(
            ref _successfulMessages);

    public long RetryCount =>
        Interlocked.Read(
            ref _retryCount);

    public long FailedMessages =>
        Interlocked.Read(
            ref _failedMessages);

    public void RecordSuccess()
    {
        Interlocked.Increment(
            ref _successfulMessages);
    }

    public void RecordRetry()
    {
        Interlocked.Increment(
            ref _retryCount);
    }

    public void RecordFailure()
    {
        Interlocked.Increment(
            ref _failedMessages);
    }
}