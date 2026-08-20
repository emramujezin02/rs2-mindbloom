namespace MindBloom.API.Configuration;

public sealed class IdempotencyOptions
{
    public const string SectionName =
        "Idempotency";

    public string HeaderName
    {
        get;
        set;
    } = "Idempotency-Key";

    public int ExpirationHours
    {
        get;
        set;
    } = 24;

    public int MaximumKeyLength
    {
        get;
        set;
    } = 128;

    public int ProcessingWaitMilliseconds
    {
        get;
        set;
    } = 5000;

    public int ProcessingPollMilliseconds
    {
        get;
        set;
    } = 100;

    public int CleanupIntervalMinutes
    {
        get;
        set;
    } = 60;
}