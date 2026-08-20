using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.API.Maintenance;

public sealed class DataRetentionCleanupService
    : BackgroundService
{
    private static readonly EventId
        CleanupCompletedEvent =
            new(
                3500,
                "DataRetentionCleanupCompleted");

    private static readonly EventId
        CleanupFailedEvent =
            new(
                3501,
                "DataRetentionCleanupFailed");

    private readonly IServiceScopeFactory
        _scopeFactory;

    private readonly DataRetentionOptions
        _options;

    private readonly ILogger<
        DataRetentionCleanupService>
        _logger;

    public DataRetentionCleanupService(
        IServiceScopeFactory scopeFactory,
        IOptions<DataRetentionOptions> options,
        ILogger<DataRetentionCleanupService>
            logger)
    {
        _scopeFactory =
            scopeFactory;

        _options =
            options.Value;

        _logger =
            logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        while (!stoppingToken
                   .IsCancellationRequested)
        {
            try
            {
                await CleanupAsync(
                    stoppingToken);
            }
            catch (OperationCanceledException)
                when (stoppingToken
                    .IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    CleanupFailedEvent,
                    exception,
                    "Data retention cleanup failed. "
                    + "Module: {Module}.",
                    "DataRetention");
            }

            try
            {
                await Task.Delay(
                    TimeSpan.FromHours(
                        _options
                            .CleanupIntervalHours),
                    stoppingToken);
            }
            catch (OperationCanceledException)
                when (stoppingToken
                    .IsCancellationRequested)
            {
                break;
            }
        }
    }

    private async Task CleanupAsync(
        CancellationToken cancellationToken)
    {
        using var scope =
            _scopeFactory.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var nowUtc =
            DateTime.UtcNow;

        var refreshTokenCutoff =
            nowUtc.AddDays(
                -_options
                    .RefreshTokenRetentionDays);

        var processedMessageCutoff =
            nowUtc.AddDays(
                -_options
                    .ProcessedMessageRetentionDays);

        var securityTokenCutoff =
            nowUtc.AddDays(
                -_options
                    .SecurityTokenRetentionDays);

        /*
         * REFRESH TOKENS
         *
         * Brišemo samo tokene koji više ne mogu
         * biti korišteni:
         *
         * 1. expired dovoljno dugo
         * 2. ili revoked dovoljno dugo
         *
         * Aktivni tokeni se nikada ne brišu.
         */
        var deletedRefreshTokens =
            await context.RefreshTokens
                .Where(token =>
                    token.ExpiresAtUtc <
                        refreshTokenCutoff
                    ||
                    (
                        token.RevokedAtUtc != null &&
                        token.RevokedAtUtc <
                            refreshTokenCutoff
                    ))
                .ExecuteDeleteAsync(
                    cancellationToken);

        /*
         * PROCESSED RABBITMQ MESSAGES
         *
         * Ovo su tehnički idempotency zapisi
         * consumera, nisu audit podaci.
         *
         * Zadržavamo ih dovoljno dugo da
         * kasni duplicate delivery ne izazove
         * ponovno procesiranje.
         */
        var deletedProcessedMessages =
            await context.ProcessedMessages
                .Where(message =>
                    message.ProcessedAtUtc <
                        processedMessageCutoff)
                .ExecuteDeleteAsync(
                    cancellationToken);

        /*
         * 2FA CHALLENGES
         *
         * Brišemo samo:
         * - istekle
         * - korištene
         * - zaključane
         *
         * i tek nakon retention perioda.
         */
        var deletedTwoFactorChallenges =
            await context
                .TwoFactorLoginChallenges
                .Where(challenge =>
                    (
                        challenge.ExpiresAtUtc <
                            securityTokenCutoff
                        ||
                        (
                            challenge.IsUsed &&
                            challenge.UsedAtUtc != null &&
                            challenge.UsedAtUtc <
                                securityTokenCutoff
                        )
                        ||
                        (
                            challenge.LockedAtUtc != null &&
                            challenge.LockedAtUtc <
                                securityTokenCutoff
                        )
                    ))
                .ExecuteDeleteAsync(
                    cancellationToken);

        /*
         * PASSWORD RESET CODES
         *
         * Reset token više nema poslovnu
         * vrijednost nakon isteka ili nakon
         * što je iskorišten.
         */
        var deletedPasswordResetCodes =
            await context.PasswordResetCodes
                .Where(code =>
                    code.ExpiresAtUtc <
                        securityTokenCutoff
                    ||
                    (
                        code.IsUsed &&
                        code.UsedAtUtc != null &&
                        code.UsedAtUtc <
                            securityTokenCutoff
                    ))
                .ExecuteDeleteAsync(
                    cancellationToken);

        /*
         * EMAIL VERIFICATION CODES
         *
         * Isti princip kao za ostale
         * kratkotrajne security kodove.
         */
        var deletedEmailVerificationCodes =
            await context
                .EmailVerificationCodes
                .Where(code =>
                    code.ExpiresAtUtc <
                        securityTokenCutoff
                    ||
                    (
                        code.IsUsed &&
                        code.ExpiresAtUtc <
                            nowUtc
                    ))
                .ExecuteDeleteAsync(
                    cancellationToken);

        var totalDeleted =
            deletedRefreshTokens
            + deletedProcessedMessages
            + deletedTwoFactorChallenges
            + deletedPasswordResetCodes
            + deletedEmailVerificationCodes;

        _logger.LogInformation(
            CleanupCompletedEvent,
            "Data retention cleanup completed. "
            + "Module: {Module}, "
            + "RefreshTokensDeleted: {RefreshTokensDeleted}, "
            + "ProcessedMessagesDeleted: {ProcessedMessagesDeleted}, "
            + "TwoFactorChallengesDeleted: {TwoFactorChallengesDeleted}, "
            + "PasswordResetCodesDeleted: {PasswordResetCodesDeleted}, "
            + "EmailVerificationCodesDeleted: {EmailVerificationCodesDeleted}, "
            + "TotalDeleted: {TotalDeleted}.",
            "DataRetention",
            deletedRefreshTokens,
            deletedProcessedMessages,
            deletedTwoFactorChallenges,
            deletedPasswordResetCodes,
            deletedEmailVerificationCodes,
            totalDeleted);
    }
}