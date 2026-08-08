namespace MindBloom.Infrastructure.Security;

public sealed class AccountLockoutSettings
{
    public const string SectionName =
        "AccountLockout";

    public int MaxFailedAccessAttempts
    {
        get;
        set;
    } = 5;

    public int LockoutMinutes
    {
        get;
        set;
    } = 15;
}