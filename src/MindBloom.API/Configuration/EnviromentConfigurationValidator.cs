namespace MindBloom.API.Configuration;

public static class EnvironmentConfigurationValidator
{
    private static readonly string[]
        RequiredApiVariables =
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
            "RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY",

            "STRIPE_SECRET_KEY",
            "STRIPE_WEBHOOK_SECRET",

            "EMAIL_USERNAME",
            "EMAIL_PASSWORD"
        ];

    public static void ValidateApi(
        IConfiguration configuration)
    {
        ValidateRequired(
            configuration,
            RequiredApiVariables,
            "MindBloom API");
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
                    StringComparer
                        .OrdinalIgnoreCase)
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
            + "the following required environment "
            + "variables are missing: "
            + string.Join(
                ", ",
                missing)
            + ".");
    }
}