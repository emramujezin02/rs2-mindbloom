namespace MindBloom.Shared.Constants;

public static class AuthorizationPolicyConstants
{
    public const string AuthenticatedUser =
        "AuthenticatedUser";

    public const string AdminOnly =
        "AdminOnly";

    public const string TherapistOnly =
        "TherapistOnly";

    public const string ClientOnly =
        "ClientOnly";

    public const string AdminOrTherapist =
        "AdminOrTherapist";

    public const string ClientOrTherapist =
        "ClientOrTherapist";
}