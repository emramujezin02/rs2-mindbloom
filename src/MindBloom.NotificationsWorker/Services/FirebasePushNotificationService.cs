using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.NotificationsWorker.Configuration;

namespace MindBloom.NotificationsWorker.Services;

public sealed class FirebasePushNotificationService
    : IPushNotificationService
{
    private static readonly EventId
    NotificationDisabledEvent =
        new(
            3600,
            "FirebaseNotificationDisabled");

    private static readonly EventId
        NoActiveTokensEvent =
            new(
                3601,
                "FirebaseNoActiveTokens");

    private static readonly EventId
        PushStartedEvent =
            new(
                3602,
                "FirebasePushStarted");

    private static readonly EventId
        PermanentTokenFailureEvent =
            new(
                3603,
                "FirebasePermanentTokenFailure");

    private static readonly EventId
        InvalidTokensEvent =
            new(
                3604,
                "FirebaseInvalidTokens");

    private static readonly EventId
        BatchProcessedEvent =
            new(
                3605,
                "FirebaseBatchProcessed");

    private static readonly EventId
        RetryExhaustedEvent =
            new(
                3606,
                "FirebaseRetryExhausted");

    private static readonly EventId
        RetryScheduledEvent =
            new(
                3607,
                "FirebaseRetryScheduled");

    private static readonly EventId
        BatchRetryExhaustedEvent =
            new(
                3608,
                "FirebaseBatchRetryExhausted");

    private static readonly EventId
        TransientBatchFailureEvent =
            new(
                3609,
                "FirebaseTransientBatchFailure");

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
                NotificationDisabledEvent,
                "Push notification skipped because notifications are disabled. Module: {Module}, UserId: {UserId}.",
                "PushNotifications",
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
                NoActiveTokensEvent,
                "Push notification skipped because user has no active FCM tokens. Module: {Module}, UserId: {UserId}.",
                "PushNotifications",
                userId);

            return;
        }

        _logger.LogInformation(
            PushStartedEvent,
            "Starting Firebase push notification. Module: {Module}, UserId: {UserId}, TokenCount: {TokenCount}.",
            "PushNotifications",
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
                        PermanentTokenFailureEvent,
                        exception,
                        "Firebase push notification permanently failed. Module: {Module}, UserId: {UserId}, TokenId: {TokenId}.",
                        "PushNotifications",
                        userId,
                        deviceToken.Id);
                }

                if (invalidTokens.Count > 0)
                {
                    InvalidateTokens(
                        invalidTokens);

                    _logger.LogWarning(
                        InvalidTokensEvent,
                        "Firebase reported invalid tokens. Module: {Module}, UserId: {UserId}, InvalidTokenCount: {InvalidTokenCount}. Tokens were deactivated.",
                        "PushNotifications",
                        userId,
                        invalidTokens.Count);
                }

                await _context.SaveChangesAsync(
                    cancellationToken);

                _logger.LogInformation(
                    BatchProcessedEvent,
                    "Firebase push batch processed. Module: {Module}, UserId: {UserId}, SuccessCount: {SuccessCount}, FailureCount: {FailureCount}, InvalidTokenCount: {InvalidTokenCount}, TransientFailureCount: {TransientFailureCount}, Attempt: {Attempt}.",
                    "PushNotifications",
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
                        RetryExhaustedEvent,
                        "Firebase push notification exhausted retry attempts. Module: {Module}, UserId: {UserId}, RemainingFailureCount: {RemainingFailureCount}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                        "PushNotifications",
                        userId,
                        transientFailures.Count,
                        attempt,
                        _options.RetryCount + 1);

                    return;
                }

                pendingTokens =
                    transientFailures;

                var retryDelay =
                    CalculateRetryDelay(
                        attempt);

                _logger.LogWarning(
                    RetryScheduledEvent,
                    "Firebase push notification retry scheduled. Module: {Module}, UserId: {UserId}, TokenCount: {TokenCount}, RetryDelaySeconds: {RetryDelaySeconds}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    "PushNotifications",
                    userId,
                    pendingTokens.Count,
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
                        BatchRetryExhaustedEvent,
                        "Firebase batch sending exhausted all retry attempts. Module: {Module}, UserId: {UserId}, FailureType: {FailureType}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                        "PushNotifications",
                        userId,
                        exception.GetType().Name,
                        attempt,
                        _options.RetryCount + 1);

                    throw;
                }

                var retryDelay =
                    CalculateRetryDelay(
                        attempt);

                _logger.LogWarning(
                    TransientBatchFailureEvent,
                    "Transient Firebase batch error. Module: {Module}, UserId: {UserId}, FailureType: {FailureType}, RetryDelaySeconds: {RetryDelaySeconds}, Attempt: {Attempt}, MaximumAttempts: {MaximumAttempts}.",
                    "PushNotifications",
                    userId,
                    exception.GetType().Name,
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