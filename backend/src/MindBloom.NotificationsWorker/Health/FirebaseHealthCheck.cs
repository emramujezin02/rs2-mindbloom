using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using MindBloom.NotificationsWorker.Configuration;

namespace MindBloom.NotificationsWorker.Health;

public sealed class FirebaseHealthCheck
    : IHealthCheck
{
    private readonly FirebaseApp
        _firebaseApp;

    private readonly FirebaseMessaging
        _firebaseMessaging;

    private readonly FirebasePushOptions
        _options;

    private readonly ILogger<
        FirebaseHealthCheck>
        _logger;

    public FirebaseHealthCheck(
        FirebaseApp firebaseApp,
        FirebaseMessaging firebaseMessaging,
        IOptions<FirebasePushOptions> options,
        ILogger<FirebaseHealthCheck>
            logger)
    {
        _firebaseApp =
            firebaseApp;

        _firebaseMessaging =
            firebaseMessaging;

        _options =
            options.Value;

        _logger =
            logger;
    }

    public Task<HealthCheckResult>
        CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken =
                default)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(
                    _options.CredentialsPath))
            {
                return Task.FromResult(
                    HealthCheckResult
                        .Unhealthy(
                            "Firebase credentials path is not configured."));
            }

            if (!File.Exists(
                    _options.CredentialsPath))
            {
                return Task.FromResult(
                    HealthCheckResult
                        .Unhealthy(
                            "Firebase credentials file does not exist."));
            }

            if (_firebaseApp is null ||
                _firebaseMessaging is null)
            {
                return Task.FromResult(
                    HealthCheckResult
                        .Unhealthy(
                            "Firebase services are not initialized."));
            }

            return Task.FromResult(
                HealthCheckResult
                    .Healthy(
                        "Firebase services are initialized."));
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Firebase health check failed.");

            return Task.FromResult(
                HealthCheckResult
                    .Unhealthy(
                        "Firebase is unavailable.",
                        exception));
        }
    }
}