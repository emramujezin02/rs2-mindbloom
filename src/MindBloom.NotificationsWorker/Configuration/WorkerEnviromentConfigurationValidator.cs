namespace MindBloom.NotificationsWorker
    .Configuration;

public static class
    WorkerEnvironmentConfigurationValidator
{
    private static readonly string[]
        RequiredVariables =
        [
            "DB_CONNECTION",

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

            "EMAIL_USERNAME",
            "EMAIL_PASSWORD",

            "FIREBASE_CREDENTIALS_PATH"
        ];

    public static void Validate(
        IConfiguration configuration)
    {
        var missing =
            RequiredVariables
                .Where(
                    variableName =>
                        string.IsNullOrWhiteSpace(
                            configuration[
                                variableName]))
                .OrderBy(
                    variableName =>
                        variableName)
                .ToList();

        if (missing.Count == 0)
        {
            return;
        }

        throw new InvalidOperationException(
            "MindBloom Notifications Worker "
            + "cannot start because the following "
            + "required environment variables "
            + "are missing: "
            + string.Join(
                ", ",
                missing)
            + ".");
    }
}