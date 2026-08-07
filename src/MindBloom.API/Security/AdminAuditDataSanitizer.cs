using System.Text.Json;
using System.Text.Json.Nodes;

namespace MindBloom.API.Security;

public static class AdminAuditDataSanitizer
{
    private const int MaximumStoredLength =
        4000;

    private static readonly HashSet<string>
        SensitivePropertyNames =
            new(
                StringComparer.OrdinalIgnoreCase)
            {
                "password",
                "passwordHash",
                "currentPassword",
                "newPassword",
                "confirmPassword",
                "confirmNewPassword",
                "token",
                "accessToken",
                "refreshToken",
                "jwt",
                "jwtToken",
                "secret",
                "clientSecret",
                "paymentSecret",
                "paymentIntentSecret",
                "clientSecretKey",
                "twoFactorCode",
                "emailVerificationCode",
                "passwordResetCode",
                "stripePaymentIntentId",
                "stripeRefundId",
                "journalContent",
                "content",
                "medicalNotes",
                "healthData",
                "diagnosis",
                "twoFactorEnabled",
                "twoFactorEnabledCustom",
                "securityStamp",
                "concurrencyStamp",
                "authenticatorKey",
                "recoveryCodes",
                "cardNumber",
                "cvv",
                "cvc",
                "iban"
            };

    private static readonly string[]
        FullyExcludedPathSegments =
            [
                "/privatejournal",
                "/private-journal",
                "/journalentries",
                "/journal-entries"
            ];

    public static string? SanitizeJson(
        string? json,
        PathString requestPath)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return null;
        }

        if (IsFullyExcludedPath(
                requestPath))
        {
            return
                "{\"data\":\"[IZOSTAVLJENO ZBOG PRIVATNOSTI]\"}";
        }

        try
        {
            var node =
                JsonNode.Parse(json);

            if (node == null)
            {
                return null;
            }

            SanitizeNode(node);

            var sanitized =
                node.ToJsonString(
                    new JsonSerializerOptions
                    {
                        WriteIndented =
                            false
                    });

            return Limit(sanitized);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static void SanitizeNode(
        JsonNode node)
    {
        if (node is JsonObject jsonObject)
        {
            foreach (var property
                     in jsonObject
                         .ToList())
            {
                if (SensitivePropertyNames
                    .Contains(property.Key))
                {
                    jsonObject[property.Key] =
                        "[MASKIRANO]";

                    continue;
                }

                if (property.Value != null)
                {
                    SanitizeNode(
                        property.Value);
                }
            }

            return;
        }

        if (node is JsonArray jsonArray)
        {
            foreach (var item
                     in jsonArray)
            {
                if (item != null)
                {
                    SanitizeNode(item);
                }
            }
        }
    }

    private static bool IsFullyExcludedPath(
        PathString path)
    {
        var normalized =
            path.Value?.ToLowerInvariant()
            ?? string.Empty;

        return FullyExcludedPathSegments
            .Any(segment =>
                normalized.Contains(
                    segment,
                    StringComparison.Ordinal));
    }

    private static string Limit(
        string value)
    {
        return value.Length <=
               MaximumStoredLength
            ? value
            : value[
                ..MaximumStoredLength];
    }
}