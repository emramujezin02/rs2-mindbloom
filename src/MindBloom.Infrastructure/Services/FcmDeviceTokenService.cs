using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class FcmDeviceTokenService
    : IFcmDeviceTokenService
{
    private static readonly EventId
    TokenRefreshedEvent =
        new(
            3500,
            "FcmTokenRefreshed");

    private static readonly EventId
        TokenRegisteredEvent =
            new(
                3501,
                "FcmTokenRegistered");

    private static readonly EventId
        TokenUnregisteredEvent =
            new(
                3502,
                "FcmTokenUnregistered");

    private readonly ApplicationDbContext
        _context;

    private readonly ILogger<
        FcmDeviceTokenService>
        _logger;

    public FcmDeviceTokenService(
        ApplicationDbContext context,
        ILogger<FcmDeviceTokenService>
            logger)
    {
        _context =
            context;

        _logger =
            logger;
    }

    public async Task RegisterAsync(
        int userId,
        RegisterFcmTokenDto request,
        CancellationToken cancellationToken =
            default)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "User identifier is invalid.",
                nameof(userId));
        }

        ArgumentNullException.ThrowIfNull(
            request);

        var token =
            request.Token.Trim();

        var platform =
            request.Platform.Trim();

        var deviceId =
            string.IsNullOrWhiteSpace(
                request.DeviceId)
                ? null
                : request.DeviceId.Trim();

        if (string.IsNullOrWhiteSpace(
                token))
        {
            throw new ArgumentException(
                "FCM token is required.");
        }

        if (string.IsNullOrWhiteSpace(
                platform))
        {
            throw new ArgumentException(
                "Device platform is required.");
        }

        var existingToken =
            await _context
                .FcmDeviceTokens
                .FirstOrDefaultAsync(
                    currentToken =>
                        currentToken.Token ==
                            token,
                    cancellationToken);

        if (existingToken is not null)
        {
            existingToken.UserId =
                userId;

            existingToken.Platform =
                platform;

            existingToken.DeviceId =
                deviceId;

            existingToken.IsActive =
                true;

            existingToken.IsDeleted =
                false;

            existingToken.InvalidatedAtUtc =
                null;

            existingToken.LastUsedAtUtc =
                DateTime.UtcNow;

            existingToken.UpdatedAtUtc =
                DateTime.UtcNow;

            await _context.SaveChangesAsync(
                cancellationToken);

            _logger.LogInformation(
                TokenRefreshedEvent,
                "FCM token refreshed. Module: {Module}, TokenId: {TokenId}, UserId: {UserId}, Platform: {Platform}.",
                "Notifications",
                existingToken.Id,
                userId,
                platform);

            return;
        }

        var fcmToken =
            new FcmDeviceToken
            {
                UserId =
                    userId,

                Token =
                    token,

                Platform =
                    platform,

                DeviceId =
                    deviceId,

                IsActive =
                    true,

                RegisteredAtUtc =
                    DateTime.UtcNow,

                LastUsedAtUtc =
                    DateTime.UtcNow
            };

        _context.FcmDeviceTokens.Add(
            fcmToken);

        await _context.SaveChangesAsync(
            cancellationToken);

        _logger.LogInformation(
            TokenRegisteredEvent,
            "FCM token registered. Module: {Module}, TokenId: {TokenId}, UserId: {UserId}, Platform: {Platform}.",
            "Notifications",
            fcmToken.Id,
            userId,
            platform);
    }

    public async Task UnregisterAsync(
        int userId,
        UnregisterFcmTokenDto request,
        CancellationToken cancellationToken =
            default)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "User identifier is invalid.",
                nameof(userId));
        }

        ArgumentNullException.ThrowIfNull(
            request);

        var token =
            request.Token.Trim();

        if (string.IsNullOrWhiteSpace(
                token))
        {
            throw new ArgumentException(
                "FCM token is required.");
        }

        var existingToken =
            await _context
                .FcmDeviceTokens
                .FirstOrDefaultAsync(
                    currentToken =>
                        currentToken.UserId ==
                            userId &&
                        currentToken.Token ==
                            token &&
                        !currentToken.IsDeleted,
                    cancellationToken);

        if (existingToken is null)
        {
            return;
        }

        existingToken.IsActive =
            false;

        existingToken.IsDeleted =
            true;

        existingToken.InvalidatedAtUtc =
            DateTime.UtcNow;

        existingToken.UpdatedAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync(
            cancellationToken);

        _logger.LogInformation(
            TokenUnregisteredEvent,
            "FCM token unregistered. Module: {Module}, TokenId: {TokenId}, UserId: {UserId}.",
            "Notifications",
            existingToken.Id,
            userId);
    }
}