namespace MindBloom.NotificationsWorker.Configuration;

public sealed class RabbitMqConsumerOptions
{
    public string HostName { get; set; } = string.Empty;

    public int Port { get; set; } = 5672;

    public string UserName { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public string VirtualHost { get; set; } = "/";

    public string ClientProvidedName { get; set; } =
        "mindbloom-notifications-worker";

    public string NotificationExchange { get; set; } =
        "mindbloom.notifications";

    public string EmailQueue { get; set; } =
        "mindbloom.notifications.email";

    public string EmailRoutingKey { get; set; } =
        "notification.email";

    public ushort PrefetchCount { get; set; } = 1;

    public bool AutomaticRecoveryEnabled { get; set; } = true;

    public int NetworkRecoveryIntervalSeconds { get; set; } = 5;

    public int RequestedHeartbeatSeconds { get; set; } = 30;
}