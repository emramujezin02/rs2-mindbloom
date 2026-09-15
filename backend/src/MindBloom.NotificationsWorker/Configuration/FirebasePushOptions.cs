namespace MindBloom.NotificationsWorker.Configuration;

public sealed class FirebasePushOptions
{
    public string CredentialsPath { get; set; } =
        string.Empty;

    public int BatchSize { get; set; } = 500;

    public int RetryCount { get; set; } = 3;

    public int RetryDelaySeconds { get; set; } = 2;
}