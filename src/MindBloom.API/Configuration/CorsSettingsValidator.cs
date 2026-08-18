using Microsoft.Extensions.Options;

namespace MindBloom.API.Configuration;

public sealed class CorsSettingsValidator
    : IValidateOptions<CorsSettings>
{
    public ValidateOptionsResult Validate(
        string? name,
        CorsSettings options)
    {
        if (options.AllowedOrigins is null)
        {
            return ValidateOptionsResult.Fail(
                "Cors:AllowedOrigins configuration is required.");
        }

        foreach (var origin in
                 options.AllowedOrigins)
        {
            if (string.IsNullOrWhiteSpace(
                    origin))
            {
                return ValidateOptionsResult.Fail(
                    "Cors:AllowedOrigins cannot contain empty values.");
            }

            if (!Uri.TryCreate(
                    origin,
                    UriKind.Absolute,
                    out var uri))
            {
                return ValidateOptionsResult.Fail(
                    "Cors:AllowedOrigins contains an invalid origin.");
            }

            if (uri.Scheme !=
                    Uri.UriSchemeHttp &&
                uri.Scheme !=
                    Uri.UriSchemeHttps)
            {
                return ValidateOptionsResult.Fail(
                    "Cors:AllowedOrigins may contain only HTTP or HTTPS origins.");
            }

            if (!string.IsNullOrEmpty(
                    uri.PathAndQuery) &&
                uri.PathAndQuery != "/")
            {
                return ValidateOptionsResult.Fail(
                    "Cors:AllowedOrigins must contain origins without URL paths.");
            }
        }

        if (options.AllowedMethods is null ||
            options.AllowedMethods.Length == 0)
        {
            return ValidateOptionsResult.Fail(
                "Cors:AllowedMethods must contain at least one HTTP method.");
        }

        if (options.AllowedHeaders is null ||
            options.AllowedHeaders.Length == 0)
        {
            return ValidateOptionsResult.Fail(
                "Cors:AllowedHeaders must contain at least one header.");
        }

        return ValidateOptionsResult.Success;
    }
}