using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Shared.Exceptions;

namespace MindBloom.Infrastructure.Services;

public class UserProfileService
    : IUserProfileService
{
    private const int MinimumNameLength = 2;
    private const int MaximumNameLength = 50;

    private static readonly Regex PhoneNumberRegex =
        new(
            @"^\+?[0-9][0-9\s\-]{6,19}$",
            RegexOptions.Compiled);

    private readonly UserManager<ApplicationUser>
        _userManager;

    public UserProfileService(
        UserManager<ApplicationUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task<UserProfileDto>
        GetCurrentUserProfileAsync(
            int userId)
    {
        var user =
            await _userManager.FindByIdAsync(
                userId.ToString());

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        return MapToDto(user);
    }

    public async Task<UserProfileDto>
        UpdateCurrentUserProfileAsync(
            int userId,
            UpdateUserProfileDto request)
    {
        ValidateRequest(request);

        var user =
            await _userManager.FindByIdAsync(
                userId.ToString());

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        user.FirstName =
            request.FirstName.Trim();

        user.LastName =
            request.LastName.Trim();

        user.PhoneNumber =
            string.IsNullOrWhiteSpace(
                request.PhoneNumber)
                ? null
                : request.PhoneNumber.Trim();

        var updateResult =
            await _userManager.UpdateAsync(user);

        if (!updateResult.Succeeded)
        {
            var errors =
                string.Join(
                    ", ",
                    updateResult.Errors.Select(
                        error =>
                            error.Description));

            throw new BusinessException(
                $"Profile could not be updated: {errors}");
        }

        return MapToDto(user);
    }

    private static void ValidateRequest(
        UpdateUserProfileDto request)
    {
        ValidateName(
            request.FirstName,
            "First name");

        ValidateName(
            request.LastName,
            "Last name");

        if (!string.IsNullOrWhiteSpace(
                request.PhoneNumber))
        {
            var phoneNumber =
                request.PhoneNumber.Trim();

            if (!PhoneNumberRegex.IsMatch(
                    phoneNumber))
            {
                throw new BadRequestException(
                    "Enter a valid phone number containing 7 to 20 characters. "
                    + "Only digits, spaces, hyphens and an optional leading + are allowed.");
            }
        }
    }

    private static void ValidateName(
        string value,
        string fieldName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new BadRequestException(
                $"{fieldName} is required.");
        }

        var trimmedValue = value.Trim();

        if (trimmedValue.Length <
            MinimumNameLength)
        {
            throw new BadRequestException(
                $"{fieldName} must contain at least "
                + $"{MinimumNameLength} characters.");
        }

        if (trimmedValue.Length >
            MaximumNameLength)
        {
            throw new BadRequestException(
                $"{fieldName} may contain at most "
                + $"{MaximumNameLength} characters.");
        }
    }

    private static UserProfileDto MapToDto(
        ApplicationUser user)
    {
        return new UserProfileDto
        {
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email
                ?? string.Empty,
            PhoneNumber = user.PhoneNumber
                ?? string.Empty,
            DateOfBirth = user.DateOfBirth,
            ProfileImageUrl =
                user.ProfileImageUrl
        };
    }
}