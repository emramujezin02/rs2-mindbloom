namespace MindBloom.Infrastructure.Messaging.RabbitMq;

public sealed class RabbitMqOptions
{
    public string HostName { get; set; } =
        string.Empty;

    public int Port { get; set; } = 5672;

    public string UserName { get; set; } =
        string.Empty;

    public string Password { get; set; } =
        string.Empty;

    public string VirtualHost { get; set; } =
        "/";

    public string PublisherClientName { get; set; } =
        string.Empty;

    public string ConsumerClientName { get; set; } =
        string.Empty;

    public string NotificationExchange { get; set; } =
        string.Empty;

    public string EmailQueue { get; set; } =
        string.Empty;

    public string EmailRoutingKey { get; set; } =
        string.Empty;

    public string RetryExchange { get; set; } =
        string.Empty;

    public string DeadLetterExchange { get; set; } =
        string.Empty;

    public string DeadLetterQueue { get; set; } =
        string.Empty;

    public string DeadLetterRoutingKey { get; set; } =
        string.Empty;

    public ushort PrefetchCount { get; set; } = 1;

    public int MaximumRetryCount { get; set; } = 4;

    public bool AutomaticRecoveryEnabled { get; set; } =
        true;

    public int NetworkRecoveryIntervalSeconds
    {
        get;
        set;
    } = 5;

    public int RequestedHeartbeatSeconds
    {
        get;
        set;
    } = 30;

    public int ConnectionRetryCount { get; set; } = 5;

    public int ConnectionRetryDelaySeconds
    {
        get;
        set;
    } = 3;
}