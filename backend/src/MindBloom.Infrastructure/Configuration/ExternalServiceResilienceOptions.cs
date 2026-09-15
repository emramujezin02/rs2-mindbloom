namespace MindBloom.Infrastructure.Configuration;

public sealed class ExternalServiceResilienceOptions
{
    public const string SectionName =
        "ExternalServiceResilience";

    public int HttpTimeoutSeconds
    {
        get;
        set;
    } = 10;

    public int HttpRetryCount
    {
        get;
        set;
    } = 3;

    public int HttpRetryBaseDelayMilliseconds
    {
        get;
        set;
    } = 500;

    public double CircuitBreakerFailureRatio
    {
        get;
        set;
    } = 0.5;

    public int CircuitBreakerMinimumThroughput
    {
        get;
        set;
    } = 5;

    public int CircuitBreakerSamplingDurationSeconds
    {
        get;
        set;
    } = 30;

    public int CircuitBreakerBreakDurationSeconds
    {
        get;
        set;
    } = 15;

    public int StripeTimeoutSeconds
    {
        get;
        set;
    } = 30;

    public int StripeMaxNetworkRetries
    {
        get;
        set;
    } = 2;
}