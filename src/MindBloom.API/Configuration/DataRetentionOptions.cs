namespace MindBloom.API.Configuration;

public sealed class DataRetentionOptions
{
    public const string SectionName =
        "DataRetention";

    public int CleanupIntervalHours
    {
        get;
        set;
    } = 6;

    public int RefreshTokenRetentionDays
    {
        get;
        set;
    } = 7;

    public int ProcessedMessageRetentionDays
    {
        get;
        set;
    } = 30;

    public int SecurityTokenRetentionDays
    {
        get;
        set;
    } = 1;
}