namespace MindBloom.NotificationsWorker.Messaging;

public static class RabbitMqHeaders
{
    public const string RetryCount = "x-retry-count";

    public const string LastFailureReason = "x-last-failure-reason";

    public const string LastFailureAtUtc = "x-last-failure-at-utc";

    public const string OriginalQueue = "x-original-queue";
}