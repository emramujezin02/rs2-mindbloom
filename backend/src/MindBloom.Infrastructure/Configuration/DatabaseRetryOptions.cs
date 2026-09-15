namespace MindBloom.Infrastructure.Configuration;

public sealed class DatabaseRetryOptions
{
    public const string SectionName =
        "DatabaseRetry";

    public int MaxRetryCount
    {
        get;
        set;
    } = 3;

    public int MaxRetryDelaySeconds
    {
        get;
        set;
    } = 5;
}