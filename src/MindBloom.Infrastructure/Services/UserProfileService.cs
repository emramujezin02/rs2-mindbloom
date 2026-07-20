using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Domain.Entities;
//using MindBloom.Shared.Exceptions;

namespace MindBloom.Infrastructure.Services;

public class UserProfileService : IUserProfileService
{
    private const int MinimumNameLength = 2;
    private const int MaximumNameLength = 50;

    private const long MaximumProfileImageSize =
        5 * 1024 * 1024;

    private static readonly Regex PhoneNumberRegex =
        new(
            @"^\+?[0-9][0-9\s\-]{6,19}$",
            RegexOptions.Compiled);

    private static readonly HashSet<string>
        AllowedExtensions =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg",
            ".jpeg",
            ".png"
        };

    private static readonly HashSet<string>
        AllowedMimeTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg",
            "image/png"
        };

    private readonly UserManager<ApplicationUser>
        _userManager;

    private readonly IWebHostEnvironment
        _environment;

    public UserProfileService(
        UserManager<ApplicationUser> userManager,
        IWebHostEnvironment environment)
    {
        _userManager = userManager;
        _environment = environment;
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

    public async Task<UserProfileDto>
        UploadProfileImageAsync(
            int userId,
            IFormFile file)
    {
        var user =
            await _userManager.FindByIdAsync(
                userId.ToString());

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        await ValidateProfileImageAsync(file);

        var webRootPath =
            _environment.WebRootPath;

        if (string.IsNullOrWhiteSpace(
                webRootPath))
        {
            webRootPath =
                Path.Combine(
                    Directory.GetCurrentDirectory(),
                    "wwwroot");
        }

        var uploadFolder =
            Path.Combine(
                webRootPath,
                "uploads",
                "profile-images");

        Directory.CreateDirectory(
            uploadFolder);

        var extension =
            Path.GetExtension(
                file.FileName)
                .ToLowerInvariant();

        var fileName =
            $"{Guid.NewGuid():N}{extension}";

        var physicalFilePath =
            Path.Combine(
                uploadFolder,
                fileName);

        await using (
            var fileStream =
                new FileStream(
                    physicalFilePath,
                    FileMode.CreateNew))
        {
            await file.CopyToAsync(
                fileStream);
        }

        var previousImageUrl =
            user.ProfileImageUrl;

        user.ProfileImageUrl =
            $"/uploads/profile-images/{fileName}";

        var updateResult =
            await _userManager.UpdateAsync(user);

        if (!updateResult.Succeeded)
        {
            if (File.Exists(
                    physicalFilePath))
            {
                File.Delete(
                    physicalFilePath);
            }

            var errors =
                string.Join(
                    ", ",
                    updateResult.Errors.Select(
                        error =>
                            error.Description));

            throw new BusinessException(
                $"Profile image could not be saved: {errors}");
        }

        DeletePreviousProfileImage(
            previousImageUrl,
            webRootPath);

        return MapToDto(user);
    }

    private static async Task
        ValidateProfileImageAsync(
            IFormFile file)
    {
        if (file == null ||
            file.Length == 0)
        {
            throw new BadRequestException(
                "Select a profile image.");
        }

        if (file.Length >
            MaximumProfileImageSize)
        {
            throw new BadRequestException(
                "Profile image may not exceed 5 MB.");
        }

        var extension =
            Path.GetExtension(
                file.FileName);

        if (string.IsNullOrWhiteSpace(
                extension) ||
            !AllowedExtensions.Contains(
                extension))
        {
            throw new BadRequestException(
                "Only JPG, JPEG and PNG images are allowed.");
        }

        if (string.IsNullOrWhiteSpace(
                file.ContentType) ||
            !AllowedMimeTypes.Contains(
                file.ContentType))
        {
            throw new BadRequestException(
                "The uploaded file has an unsupported content type.");
        }

        var header = new byte[8];

        await using var stream =
            file.OpenReadStream();

        var bytesRead =
            await stream.ReadAsync(
                header.AsMemory(
                    0,
                    header.Length));

        var isJpeg =
            bytesRead >= 3 &&
            header[0] == 0xFF &&
            header[1] == 0xD8 &&
            header[2] == 0xFF;

        var isPng =
            bytesRead >= 8 &&
            header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4E &&
            header[3] == 0x47 &&
            header[4] == 0x0D &&
            header[5] == 0x0A &&
            header[6] == 0x1A &&
            header[7] == 0x0A;

        if (!isJpeg && !isPng)
        {
            throw new BadRequestException(
                "The uploaded file is not a valid JPG or PNG image.");
        }

        if (file.ContentType.Equals(
                "image/png",
                StringComparison.OrdinalIgnoreCase) &&
            !isPng)
        {
            throw new BadRequestException(
                "The file content does not match its PNG content type.");
        }

        if (file.ContentType.Equals(
                "image/jpeg",
                StringComparison.OrdinalIgnoreCase) &&
            !isJpeg)
        {
            throw new BadRequestException(
                "The file content does not match its JPEG content type.");
        }
    }

    private static void
        DeletePreviousProfileImage(
            string? previousImageUrl,
            string webRootPath)
    {
        if (string.IsNullOrWhiteSpace(
                previousImageUrl))
        {
            return;
        }

        const string allowedPrefix =
            "/uploads/profile-images/";

        if (!previousImageUrl.StartsWith(
                allowedPrefix,
                StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var relativePath =
            previousImageUrl
                .TrimStart('/')
                .Replace(
                    '/',
                    Path.DirectorySeparatorChar);

        var fullPath =
            Path.GetFullPath(
                Path.Combine(
                    webRootPath,
                    relativePath));

        var allowedFolder =
            Path.GetFullPath(
                Path.Combine(
                    webRootPath,
                    "uploads",
                    "profile-images"));

        if (!fullPath.StartsWith(
                allowedFolder,
                StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }
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
        if (string.IsNullOrWhiteSpace(
                value))
        {
            throw new BadRequestException(
                $"{fieldName} is required.");
        }

        var trimmedValue =
            value.Trim();

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
            FirstName =
                user.FirstName,

            LastName =
                user.LastName,

            Email =
                user.Email
                ?? string.Empty,

            PhoneNumber =
                user.PhoneNumber
                ?? string.Empty,

            DateOfBirth =
                user.DateOfBirth,

            ProfileImageUrl =
                user.ProfileImageUrl
        };
    }
}