namespace MindBloom.Application.Features.Privacy.DTOs;

public sealed class CurrentConsentVersionsDto
{
    public string PrivacyPolicyVersion
    {
        get;
        set;
    } = string.Empty;

    public string TermsOfServiceVersion
    {
        get;
        set;
    } = string.Empty;

    public string SensitiveDataProcessingVersion
    {
        get;
        set;
    } = string.Empty;

    public string SensitiveDataUsageExplanation
    {
        get;
        set;
    } = string.Empty;
}