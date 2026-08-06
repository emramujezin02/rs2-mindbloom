using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class UserSettingsService
    : IUserSettingsService
{
    private readonly ApplicationDbContext _context;

    public UserSettingsService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<UserSettingsDto> GetAsync(
        int userId)
    {
        var userExists =
            await _context.Users
                .AsNoTracking()
                .AnyAsync(user =>
                    user.Id == userId);

        if (!userExists)
        {
            throw new NotFoundException(
                "User not found.");
        }

        var settings =
            await _context.UserSettings
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    !x.IsDeleted);

        if (settings == null)
        {
            return new UserSettingsDto
            {
                NotificationsEnabled = true,
                ShowProfilePublicly = true
            };
        }

        return MapToDto(settings);
    }

    public async Task<UserSettingsDto> UpdateAsync(
        int userId,
        UpdateUserSettingsDto request)
    {
        var userExists =
            await _context.Users
                .AnyAsync(user =>
                    user.Id == userId);

        if (!userExists)
        {
            throw new NotFoundException(
                "User not found.");
        }

        var settings =
            await _context.UserSettings
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId);

        if (settings == null)
        {
            settings = new UserSettings
            {
                UserId =
                    userId,

                NotificationsEnabled =
                    request.NotificationsEnabled,

                ShowProfilePublicly =
                    request.ShowProfilePublicly,

                ShareMoodAndEmotionsWithTherapists =
                    request
                        .ShareMoodAndEmotionsWithTherapists
            };

            _context.UserSettings.Add(settings);
        }
        else
        {
            settings.IsDeleted = false;

            settings.NotificationsEnabled =
                request.NotificationsEnabled;

            settings.ShowProfilePublicly =
                request.ShowProfilePublicly;

            settings.ShareMoodAndEmotionsWithTherapists =
    request
        .ShareMoodAndEmotionsWithTherapists;
        }

        await _context.SaveChangesAsync();

        return MapToDto(settings);
    }

    private static UserSettingsDto MapToDto(
        UserSettings settings)
    {
        return new UserSettingsDto
        {
            NotificationsEnabled =
                settings.NotificationsEnabled,

            ShowProfilePublicly =
                settings.ShowProfilePublicly,

            ShareMoodAndEmotionsWithTherapists =
                settings
                    .ShareMoodAndEmotionsWithTherapists
        };
    }
}