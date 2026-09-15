namespace MindBloom.API.Configuration;

public sealed class RequestTimingOptions
{
    public const string SectionName =
        "RequestTiming";

    public int SlowRequestThresholdMilliseconds
    {
        get;
        set;
    } = 1000;
}