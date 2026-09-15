namespace MindBloom.SecurityTests.Infrastructure;

internal static class TestEnvironmentLoader
{
    public static void LoadRootDotEnv()
    {
        var rootPath =
            FindRepositoryRoot();

        if (rootPath is null)
        {
            return;
        }

        var dotEnvPath =
            Path.Combine(
                rootPath,
                ".env");

        if (!File.Exists(dotEnvPath))
        {
            return;
        }

        foreach (var line in File.ReadLines(dotEnvPath))
        {
            var trimmed =
                line.Trim();

            if (string.IsNullOrWhiteSpace(trimmed) ||
                trimmed.StartsWith("#", StringComparison.Ordinal))
            {
                continue;
            }

            var separatorIndex =
                trimmed.IndexOf('=');

            if (separatorIndex <= 0)
            {
                continue;
            }

            var key =
                trimmed[..separatorIndex].Trim();

            if (string.IsNullOrWhiteSpace(key) ||
                !string.IsNullOrWhiteSpace(
                    Environment.GetEnvironmentVariable(key)))
            {
                continue;
            }

            var value =
                trimmed[(separatorIndex + 1)..].Trim();

            Environment.SetEnvironmentVariable(
                key,
                Unquote(value));
        }
    }

    public static void ConfigureSqlConnectionFromDotEnv()
    {
        if (!string.IsNullOrWhiteSpace(
                Environment.GetEnvironmentVariable(
                    "TEST_SQL_CONNECTION")))
        {
            return;
        }

        var password =
            Environment.GetEnvironmentVariable(
                "SQL_SERVER_PASSWORD");

        if (string.IsNullOrWhiteSpace(password))
        {
            return;
        }

        var port =
            Environment.GetEnvironmentVariable(
                "SQL_SERVER_PORT");

        if (string.IsNullOrWhiteSpace(port))
        {
            port =
                "1433";
        }

        Environment.SetEnvironmentVariable(
            "TEST_SQL_CONNECTION",
            "Server=localhost,"
            + port
            + ";Database=master;"
            + "User Id=sa;"
            + "Password="
            + password
            + ";TrustServerCertificate=True;"
            + "Encrypt=False;");
    }

    private static string? FindRepositoryRoot()
    {
        var directory =
            new DirectoryInfo(
                AppContext.BaseDirectory);

        while (directory is not null)
        {
            if (File.Exists(
                    Path.Combine(
                        directory.FullName,
                        "MindBloom.sln")))
            {
                return directory.FullName;
            }

            directory =
                directory.Parent;
        }

        return null;
    }

    private static string Unquote(
        string value)
    {
        if (value.Length >= 2 &&
            ((value[0] == '"' &&
              value[^1] == '"') ||
             (value[0] == '\'' &&
              value[^1] == '\'')))
        {
            return value[1..^1];
        }

        return value;
    }
}
