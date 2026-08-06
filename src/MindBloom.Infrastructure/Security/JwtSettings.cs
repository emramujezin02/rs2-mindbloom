namespace MindBloom.Infrastructure.Security;

public class JwtSettings
{
    public const int MinimumSecretLength =
        32;

    public const int MinimumExpirationMinutes =
        5;

    public const int MaximumExpirationMinutes =
        60;

    public string SecretKey { get; set; } =
        string.Empty;

    public string Issuer { get; set; } =
        string.Empty;

    public string Audience { get; set; } =
        string.Empty;

    public int ExpirationInMinutes
    {
        get;
        set;
    } = 15;
}