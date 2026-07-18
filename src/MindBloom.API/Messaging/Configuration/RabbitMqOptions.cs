namespace MindBloom.API.Messaging.Configuration;

public sealed class RabbitMqOptions
{
    public const string SectionName = "RabbitMq";

    public string HostName { get; set; } = string.Empty;

    public int Port { get; set; } = 5672;

    public string UserName { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public string VirtualHost { get; set; } = "/";

    public string ClientProvidedName { get; set; } =
        "mindbloom-api-notification-publisher";

    public string NotificationExchange { get; set; } =
        "mindbloom.notifications";

    public string EmailQueue { get; set; } =
        "mindbloom.notifications.email";

    public string EmailRoutingKey { get; set; } =
        "notification.email";

    public bool AutomaticRecoveryEnabled { get; set; } = true;

    public int NetworkRecoveryIntervalSeconds { get; set; } = 5;

    public int RequestedHeartbeatSeconds { get; set; } = 30;
}