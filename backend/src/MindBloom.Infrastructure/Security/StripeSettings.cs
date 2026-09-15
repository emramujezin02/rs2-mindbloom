namespace MindBloom.Infrastructure.Security;

public sealed class StripeSettings
{
    public string SecretKey { get; set; } =
        string.Empty;

    public string WebhookSecret { get; set; } =
        string.Empty;

    public string Currency { get; set; } =
        "usd";
}