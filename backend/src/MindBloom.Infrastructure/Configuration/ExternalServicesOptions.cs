namespace MindBloom.Infrastructure.Configuration;

public sealed class ExternalServicesOptions
{
    public const string SectionName =
        "ExternalServices";

    public bool PaymentsEnabled
    {
        get;
        set;
    } = true;

    public bool EmailEnabled
    {
        get;
        set;
    } = true;

    public bool FirebaseEnabled
    {
        get;
        set;
    } = true;
}