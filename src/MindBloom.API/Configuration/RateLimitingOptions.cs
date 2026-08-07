namespace MindBloom.API.Configuration;

public sealed class RateLimitingOptions
{
    public const string SectionName =
        "RateLimiting";

    public RateLimitRuleOptions Login { get; set; } =
        new()
        {
            PermitLimit = 5,
            WindowSeconds = 300
        };

    public RateLimitRuleOptions Registration { get; set; } =
        new()
        {
            PermitLimit = 5,
            WindowSeconds = 600
        };

    public RateLimitRuleOptions ForgotPassword { get; set; } =
        new()
        {
            PermitLimit = 3,
            WindowSeconds = 900
        };

    public RateLimitRuleOptions ResetPassword { get; set; } =
        new()
        {
            PermitLimit = 5,
            WindowSeconds = 900
        };

    public RateLimitRuleOptions TwoFactorLogin { get; set; } =
        new()
        {
            PermitLimit = 3,
            WindowSeconds = 300
        };

    public RateLimitRuleOptions TwoFactorVerify { get; set; } =
        new()
        {
            PermitLimit = 10,
            WindowSeconds = 300
        };

    public RateLimitRuleOptions TwoFactorSettings { get; set; } =
        new()
        {
            PermitLimit = 5,
            WindowSeconds = 600
        };

    public RateLimitRuleOptions RefreshToken { get; set; } =
        new()
        {
            PermitLimit = 10,
            WindowSeconds = 300
        };

    public RateLimitRuleOptions ChatMessages { get; set; } =
        new()
        {
            PermitLimit = 30,
            WindowSeconds = 60
        };

    public RateLimitRuleOptions Uploads { get; set; } =
        new()
        {
            PermitLimit = 10,
            WindowSeconds = 600
        };

    public RateLimitRuleOptions Recommendations { get; set; } =
        new()
        {
            PermitLimit = 20,
            WindowSeconds = 300
        };

    public RateLimitRuleOptions PublicSearch { get; set; } =
        new()
        {
            PermitLimit = 60,
            WindowSeconds = 60
        };
}

public sealed class RateLimitRuleOptions
{
    public int PermitLimit { get; set; }

    public int WindowSeconds { get; set; }

    public int QueueLimit { get; set; } = 0;
}