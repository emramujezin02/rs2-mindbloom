using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.NotificationsWorker.Configuration;

namespace MindBloom.NotificationsWorker.Services;

public sealed class FirebasePushNotificationService
    : IPushNotificationService
{
    private const string SafePushTitle =
    "MindBloom";

    private const string SafePushMessage =
        "You have a new notification.";

    private static readonly string[]
        SensitiveDataKeyFragments =
        [
            "journal",
        "mood",
        "emotion",
        "assessment",
        "diagnosis",
        "health",
        "medical",
        "note",
        "content",
        "message",
        "body"
        ];

    private readonly ApplicationDbContext
        _context;

    private readonly FirebaseMessaging
        _firebaseMessaging;

    private readonly FirebasePushOptions
        _options;

    private readonly ILogger<
        FirebasePushNotificationService>
        _logger;

    public FirebasePushNotificationService(
        ApplicationDbContext context,
        FirebaseMessaging firebaseMessaging,
        Microsoft.Extensions.Options
            .IOptions<FirebasePushOptions> options,
        ILogger<FirebasePushNotificationService>
            logger)
    {
        _context =
            context;

        _firebaseMessaging =
            firebaseMessaging;

        _options =
            options.Value;

        _logger =
            logger;
    }

    public async Task SendToUserAsync(
        int userId,
        string title,
        string message,
        IReadOnlyDictionary<string, string>?
            data = null,
        CancellationToken cancellationToken =
            default)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "Push notification user identifier is invalid.",
                nameof(userId));
        }

        var normalizedTitle =
            title?.Trim() ??
            string.Empty;

        var normalizedMessage =
            message?.Trim() ??
            string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedTitle))
        {
            throw new ArgumentException(
                "Push notification title is required.",
                nameof(title));
        }

        if (string.IsNullOrWhiteSpace(
                normalizedMessage))
        {
            throw new ArgumentException(
                "Push notification message is required.",
                nameof(message));
        }

        var notificationsEnabled =
            await _context.UserSettings
                .AsNoTracking()
                .Where(settings =>
                    settings.UserId == userId &&
                    !settings.IsDeleted)
                .Select(settings =>
                    (bool?)settings
                        .NotificationsEnabled)
                .FirstOrDefaultAsync(
                    cancellationToken);

        if (notificationsEnabled == false)
        {
            _logger.LogInformation(
                "Push notification skipped because notifications are disabled for user {UserId}.",
                userId);

            return;
        }

        var deviceTokens =
            await _context.FcmDeviceTokens
                .Where(deviceToken =>
                    deviceToken.UserId ==
                        userId &&
                    deviceToken.IsActive &&
                    !deviceToken.IsDeleted)
                .OrderBy(deviceToken =>
                    deviceToken.Id)
                .ToListAsync(
                    cancellationToken);

        if (deviceTokens.Count == 0)
        {
            _logger.LogDebug(
                "Push notification skipped because user {UserId} has no active FCM tokens.",
                userId);

            return;
        }

        _logger.LogInformation(
            "Starting Firebase push notification for user {UserId}. Active token count: {TokenCount}.",
            userId,
            deviceTokens.Count);

        var batchSize =
            Math.Clamp(
                _options.BatchSize,
                1,
                500);

        foreach (var tokenBatch
                 in deviceTokens.Chunk(
                     batchSize))
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            var safeData =
                SanitizePushData(data);

            await SendBatchWithRetryAsync(
                userId,
                SafePushTitle,
                SafePushMessage,
                safeData,
                tokenBatch,
                cancellationToken);
        }
    }

    private async Task SendBatchWithRetryAsync(
        int userId,
        string title,
        string message,
        IReadOnlyDictionary<string, string>?
            data,
        IReadOnlyCollection<
            MindBloom.Domain.Entities
                .FcmDeviceToken> deviceTokens,
        CancellationToken cancellationToken)
    {
        var pendingTokens =
            deviceTokens.ToList();

        var attempt =
            0;

        while (pendingTokens.Count > 0)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            attempt++;

            var tokenValues =
                pendingTokens
                    .Select(x => x.Token)
                    .ToList();

            try
            {
                var multicastMessage =
                    new MulticastMessage
                    {
                        Tokens =
                            tokenValues,

                        Notification =
                            new FirebaseAdmin
                                .Messaging
                                .Notification
                            {
                                Title =
                                        title,

                                Body =
                                        message
                            },

                        Data =
                            data is null
                                ? null
                                : new Dictionary<
                                    string,
                                    string>(
                                    data)
                    };

                var response =
                    await _firebaseMessaging
                        .SendEachForMulticastAsync(
                            multicastMessage,
                            cancellationToken);

                var transientFailures =
                    new List<
                        MindBloom.Domain.Entities
                            .FcmDeviceToken>();

                var invalidTokens =
                    new List<
                        MindBloom.Domain.Entities
                            .FcmDeviceToken>();

                for (var index = 0;
                     index <
                     response.Responses.Count;
                     index++)
                {
                    var sendResponse =
                        response.Responses[
                            index];

                    var deviceToken =
                        pendingTokens[index];

                    if (sendResponse.IsSuccess)
                    {
                        deviceToken.LastUsedAtUtc =
                            DateTime.UtcNow;

                        continue;
                    }

                    var exception =
                        sendResponse.Exception;

                    if (IsInvalidTokenError(
                            exception))
                    {
                        invalidTokens.Add(
                            deviceToken);

                        continue;
                    }

                    if (IsTransientError(
                            exception))
                    {
                        transientFailures.Add(
                            deviceToken);

                        continue;
                    }

                    _logger.LogError(
                        exception,
                        "Firebase push notification permanently failed for user {UserId}. Token ID: {TokenId}.",
                        userId,
                        deviceToken.Id);
                }

                if (invalidTokens.Count > 0)
                {
                    InvalidateTokens(
                        invalidTokens);

                    _logger.LogWarning(
                        "Firebase reported {InvalidTokenCount} invalid tokens for user {UserId}. Tokens were deactivated.",
                        invalidTokens.Count,
                        userId);
                }

                await _context.SaveChangesAsync(
                    cancellationToken);

                _logger.LogInformation(
                    "Firebase push batch processed for user {UserId}. "
                    + "Success: {SuccessCount}, "
                    + "Failure: {FailureCount}, "
                    + "invalid tokens: {InvalidTokenCount}, "
                    + "transient failures: {TransientFailureCount}, "
                    + "attempt: {Attempt}.",
                    userId,
                    response.SuccessCount,
                    response.FailureCount,
                    invalidTokens.Count,
                    transientFailures.Count,
                    attempt);

                if (transientFailures.Count == 0)
                {
                    return;
                }

                if (attempt >=
                    _options.RetryCount + 1)
                {
                    _logger.LogError(
                        "Firebase push notification exhausted retry attempts for user {UserId}. Remaining transient failures: {FailureCount}.",
                        userId,
                        transientFailures.Count);

                    return;
                }

                pendingTokens =
                    transientFailures;

                var retryDelay =
                    CalculateRetryDelay(
                        attempt);

                _logger.LogWarning(
                    "Firebase push notification will retry {TokenCount} transient failures for user {UserId} after {RetryDelaySeconds} seconds. Attempt {Attempt}/{MaximumAttempts}.",
                    pendingTokens.Count,
                    userId,
                    retryDelay.TotalSeconds,
                    attempt + 1,
                    _options.RetryCount + 1);

                await Task.Delay(
                    retryDelay,
                    cancellationToken);
            }
            catch (OperationCanceledException)
                when (cancellationToken
                    .IsCancellationRequested)
            {
                throw;
            }
            catch (FirebaseMessagingException
                   exception)
                when (IsTransientError(
                    exception))
            {
                if (attempt >=
                    _options.RetryCount + 1)
                {
                    _logger.LogError(
                        exception,
                        "Firebase batch sending exhausted all retry attempts for user {UserId}.",
                        userId);

                    throw;
                }

                var retryDelay =
                    CalculateRetryDelay(
                        attempt);

                _logger.LogWarning(
                    exception,
                    "Transient Firebase batch error for user {UserId}. Retry in {RetryDelaySeconds} seconds. Attempt {Attempt}/{MaximumAttempts}.",
                    userId,
                    retryDelay.TotalSeconds,
                    attempt + 1,
                    _options.RetryCount + 1);

                await Task.Delay(
                    retryDelay,
                    cancellationToken);
            }
        }
    }

    private TimeSpan CalculateRetryDelay(
        int attempt)
    {
        /*
         * Exponential backoff:
         *
         * base 2s:
         * 2s -> 4s -> 8s ...
         */
        var multiplier =
            Math.Pow(
                2,
                Math.Max(
                    0,
                    attempt - 1));

        var seconds =
            _options.RetryDelaySeconds *
            multiplier;

        return TimeSpan.FromSeconds(
            Math.Min(
                seconds,
                60));
    }

    private static bool IsInvalidTokenError(
        FirebaseMessagingException?
            exception)
    {
        if (exception is null)
        {
            return false;
        }

        return exception.MessagingErrorCode
            is MessagingErrorCode.Unregistered
            or MessagingErrorCode.SenderIdMismatch;
    }

    private static bool IsTransientError(
        FirebaseMessagingException?
            exception)
    {
        if (exception is null)
        {
            return false;
        }

        return exception.MessagingErrorCode
            is MessagingErrorCode.Unavailable
            or MessagingErrorCode.Internal
            or MessagingErrorCode.QuotaExceeded;
    }

    private static void InvalidateTokens(
        IEnumerable<
            MindBloom.Domain.Entities
                .FcmDeviceToken> tokens)
    {
        var now =
            DateTime.UtcNow;

        foreach (var token
                 in tokens)
        {
            token.IsActive =
                false;

            token.InvalidatedAtUtc =
                now;
        }
    }

    private static IReadOnlyDictionary<
    string,
    string>?
    SanitizePushData(
        IReadOnlyDictionary<
            string,
            string>? data)
    {
        if (data == null ||
            data.Count == 0)
        {
            return data;
        }

        var safeData =
            new Dictionary<
                string,
                string>(
                StringComparer.OrdinalIgnoreCase);

        foreach (var item in data)
        {
            if (IsSensitivePushDataKey(
                    item.Key))
            {
                continue;
            }

            safeData[item.Key] =
                item.Value;
        }

        return safeData.Count == 0
            ? null
            : safeData;
    }

    private static bool
        IsSensitivePushDataKey(
            string key)
    {
        if (string.IsNullOrWhiteSpace(
                key))
        {
            return true;
        }

        return SensitiveDataKeyFragments
            .Any(fragment =>
                key.Contains(
                    fragment,
                    StringComparison
                        .OrdinalIgnoreCase));
    }
}