using MindBloom.Infrastructure.Configuration;

namespace MindBloom.API.Configuration;

public static class
    EnvironmentConfigurationValidator
{
    private static readonly string[]
        AlwaysRequiredVariables =
        [
            "DB_CONNECTION",

            "JWT_SECRET",
            "JWT_ISSUER",
            "JWT_AUDIENCE",
            "JWT_EXPIRATION_MINUTES",

            "RABBITMQ_HOST",
            "RABBITMQ_PORT",
            "RABBITMQ_USERNAME",
            "RABBITMQ_PASSWORD",
            "RABBITMQ_VIRTUAL_HOST",

            "RABBITMQ_CLIENT_NAME",
            "RABBITMQ_WORKER_CLIENT_NAME",

            "RABBITMQ_NOTIFICATION_EXCHANGE",
            "RABBITMQ_EMAIL_QUEUE",
            "RABBITMQ_EMAIL_ROUTING_KEY",

            "RABBITMQ_RETRY_EXCHANGE",
            "RABBITMQ_DEAD_LETTER_EXCHANGE",
            "RABBITMQ_EMAIL_DEAD_LETTER_QUEUE",
            "RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY"
        ];

    public static void ValidateApi(
        IConfiguration configuration)
    {
        var requiredVariables =
            new List<string>(
                AlwaysRequiredVariables);

        var externalServices =
            configuration
                .GetSection(
                    ExternalServicesOptions.SectionName)
                .Get<ExternalServicesOptions>()
            ?? new ExternalServicesOptions();

        if (externalServices.PaymentsEnabled)
        {
            requiredVariables.Add(
                "STRIPE_SECRET_KEY");

            requiredVariables.Add(
                "STRIPE_WEBHOOK_SECRET");
        }

        if (externalServices.EmailEnabled)
        {
            requiredVariables.Add(
                "EMAIL_USERNAME");

            requiredVariables.Add(
                "EMAIL_PASSWORD");
        }

        ValidateRequired(
            configuration,
            requiredVariables,
            "MindBloom API");

        ValidateConnectionString(
            configuration);

        ValidateJwt(
            configuration);

        ValidateRabbitMqPort(
            configuration);

        ValidateUploadConfiguration(
            configuration);
    }

    private static void ValidateRequired(
        IConfiguration configuration,
        IEnumerable<string> variableNames,
        string componentName)
    {
        var missing =
            variableNames
                .Where(
                    variableName =>
                        string.IsNullOrWhiteSpace(
                            configuration[
                                variableName]))
                .Distinct(
                    StringComparer.OrdinalIgnoreCase)
                .OrderBy(
                    variableName =>
                        variableName)
                .ToList();

        if (missing.Count == 0)
        {
            return;
        }

        throw new InvalidOperationException(
            $"{componentName} cannot start because "
            + "the following required configuration "
            + "values are missing: "
            + string.Join(
                ", ",
                missing)
            + ".");
    }

    private static void ValidateConnectionString(
        IConfiguration configuration)
    {
        var connectionString =
            configuration[
                "DB_CONNECTION"];

        if (string.IsNullOrWhiteSpace(
                connectionString))
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'DB_CONNECTION' is required.");
        }
    }

    private static void ValidateJwt(
        IConfiguration configuration)
    {
        var secret =
            configuration[
                "JWT_SECRET"];

        if (string.IsNullOrWhiteSpace(
                secret))
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'JWT_SECRET' is required.");
        }

        if (System.Text.Encoding.UTF8
                .GetByteCount(secret) <
            MindBloom.Infrastructure.Security
                .JwtSettings.MinimumSecretLength)
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'JWT_SECRET' does not meet "
                + "the minimum required length.");
        }

        var expirationValue =
            configuration[
                "JWT_EXPIRATION_MINUTES"];

        if (!int.TryParse(
                expirationValue,
                out var expirationMinutes))
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'JWT_EXPIRATION_MINUTES' "
                + "must be a valid integer.");
        }

        if (expirationMinutes <
                MindBloom.Infrastructure.Security
                    .JwtSettings
                    .MinimumExpirationMinutes ||
            expirationMinutes >
                MindBloom.Infrastructure.Security
                    .JwtSettings
                    .MaximumExpirationMinutes)
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'JWT_EXPIRATION_MINUTES' "
                + "is outside the allowed range.");
        }
    }

    private static void ValidateRabbitMqPort(
        IConfiguration configuration)
    {
        var portValue =
            configuration[
                "RABBITMQ_PORT"];

        if (!int.TryParse(
                portValue,
                out var port) ||
            port is <= 0 or > 65535)
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'RABBITMQ_PORT' "
                + "must be between 1 and 65535.");
        }
    }

    private static void ValidateUploadConfiguration(
        IConfiguration configuration)
    {
        var rootPath =
            configuration[
                "UPLOAD_ROOT_PATH"];

        if (string.IsNullOrWhiteSpace(
                rootPath))
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'UPLOAD_ROOT_PATH' is required.");
        }

        var normalized =
            rootPath.Trim();

        if (Path.IsPathRooted(
                normalized))
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'UPLOAD_ROOT_PATH' must be "
                + "a relative application path.");
        }

        var segments =
            normalized
                .Replace(
                    '\\',
                    '/')
                .Split(
                    '/',
                    StringSplitOptions
                        .RemoveEmptyEntries);

        if (segments.Any(
                segment =>
                    segment == ".."))
        {
            throw new InvalidOperationException(
                "Configuration value "
                + "'UPLOAD_ROOT_PATH' contains "
                + "an invalid parent-directory segment.");
        }
    }
}