using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using MindBloom.Infrastructure.Persistence.Context;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Configuration;

namespace MindBloom.Infrastructure.Services;

public class UserProfileService : IUserProfileService
{

    private readonly UploadSettings
    _uploadSettings;


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
    private readonly ApplicationDbContext _context;

    public UserProfileService(
        UserManager<ApplicationUser> userManager,
        IWebHostEnvironment environment,
        ApplicationDbContext context,
        IOptions<UploadSettings> uploadSettings)
    {
        _userManager = userManager;
        _environment = environment;
        _context = context;
        _uploadSettings =
    uploadSettings.Value;
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

        var client =
            await _context.Clients
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    !x.IsDeleted);

        return MapToDto(user, client);
    }

    public async Task<UserProfileDto>
     UpdateCurrentUserProfileAsync(
         int userId,
         UpdateUserProfileDto request)
    {
        ValidateProfileRequest(request);

        var user =
            await _userManager.FindByIdAsync(
                userId.ToString());

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    !x.IsDeleted);

        user.FirstName =
            request.FirstName.Trim();

        user.LastName =
            request.LastName.Trim();

        user.PhoneNumber =
            string.IsNullOrWhiteSpace(
                request.PhoneNumber)
                ? null
                : request.PhoneNumber.Trim();

        user.DateOfBirth =
            request.DateOfBirth.Date;

        if (client != null)
        {
            client.Location =
                NormalizeNullableText(
                    request.Location);

            client.PreferredTherapistGender =
                NormalizeNullableText(
                    request.PreferredTherapistGender);

            client.PreferredSessionType =
                NormalizeNullableText(
                    request.PreferredSessionType);

            client.MinimumPricePerSession =
                request.MinimumPricePerSession;

            client.MaximumPricePerSession =
                request.MaximumPricePerSession;

            client.PreferredLanguages =
                NormalizeLanguages(
                    request.PreferredLanguages);
        }

        var updateResult =
            await _userManager.UpdateAsync(
                user);

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

        await _context.SaveChangesAsync();

        return MapToDto(
            user,
            client);
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

        var client =
    await _context.Clients
        .AsNoTracking()
        .FirstOrDefaultAsync(x =>
            x.UserId == userId &&
            !x.IsDeleted);

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
                _uploadSettings.RootFolder,
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

        return MapToDto(user, client);
    }

    private async Task
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
            _uploadSettings.MaximumImageSizeBytes)
        {
            throw new BadRequestException(
                $"Profile image may not exceed "
+ $"{_uploadSettings.MaximumImageSizeMb} MB.");
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


    private static void ValidateProfileRequest(
        UpdateUserProfileDto request)
    {
        var firstName =
            request.FirstName?.Trim() ?? string.Empty;

        var lastName =
            request.LastName?.Trim() ?? string.Empty;

        if (firstName.Length < 2 ||
            firstName.Length > 50)
        {
            throw new BadRequestException(
                "First name must contain between 2 and 50 characters.");
        }

        if (lastName.Length < 2 ||
            lastName.Length > 50)
        {
            throw new BadRequestException(
                "Last name must contain between 2 and 50 characters.");
        }

        var today = DateTime.UtcNow.Date;

        if (request.DateOfBirth.Date >= today)
        {
            throw new BadRequestException(
                "Date of birth must be in the past.");
        }

        if (request.DateOfBirth.Date <
            today.AddYears(-120))
        {
            throw new BadRequestException(
                "Date of birth is not valid.");
        }

        var phoneNumber =
            request.PhoneNumber?.Trim();

        if (!string.IsNullOrWhiteSpace(phoneNumber))
        {
            if (phoneNumber.Length < 7 ||
                phoneNumber.Length > 20)
            {
                throw new BadRequestException(
                    "Phone number must contain between 7 and 20 characters.");
            }

            var validCharacters =
                phoneNumber.All(character =>
                    char.IsDigit(character) ||
                    character == '+' ||
                    character == '-' ||
                    character == ' ');

            if (!validCharacters)
            {
                throw new BadRequestException(
                    "Phone number contains invalid characters.");
            }

            if (phoneNumber.Count(x => x == '+') > 1 ||
                phoneNumber.Contains('+') &&
                !phoneNumber.StartsWith('+'))
            {
                throw new BadRequestException(
                    "The plus sign may only appear at the beginning.");
            }
        }

        if (!string.IsNullOrWhiteSpace(request.Location) &&
            request.Location.Trim().Length > 200)
        {
            throw new BadRequestException(
                "Location may contain at most 200 characters.");
        }

        var allowedGenders =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "Any",
            "Female",
            "Male"
            };

        if (!string.IsNullOrWhiteSpace(
                request.PreferredTherapistGender) &&
            !allowedGenders.Contains(
                request.PreferredTherapistGender.Trim()))
        {
            throw new BadRequestException(
                "Preferred therapist gender must be Any, Female or Male.");
        }

        var allowedSessionTypes =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "Any",
            "Online",
            "InPerson"
            };

        if (!string.IsNullOrWhiteSpace(
                request.PreferredSessionType) &&
            !allowedSessionTypes.Contains(
                request.PreferredSessionType.Trim()))
        {
            throw new BadRequestException(
                "Preferred session type must be Any, Online or InPerson.");
        }

        if (request.MinimumPricePerSession.HasValue &&
            request.MinimumPricePerSession.Value < 0)
        {
            throw new BadRequestException(
                "Minimum price cannot be negative.");
        }

        if (request.MaximumPricePerSession.HasValue &&
            request.MaximumPricePerSession.Value < 0)
        {
            throw new BadRequestException(
                "Maximum price cannot be negative.");
        }

        if (request.MinimumPricePerSession.HasValue &&
            request.MaximumPricePerSession.HasValue &&
            request.MinimumPricePerSession.Value >
            request.MaximumPricePerSession.Value)
        {
            throw new BadRequestException(
                "Minimum price cannot be greater than maximum price.");
        }

        var preferredLanguages =
            request.PreferredLanguages?
                .Where(x =>
                    !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim())
                .Distinct(
                    StringComparer.OrdinalIgnoreCase)
                .ToList()
            ?? [];

        if (preferredLanguages.Count > 10)
        {
            throw new BadRequestException(
                "You may select at most 10 preferred languages.");
        }

        if (preferredLanguages.Any(x =>
                x.Length > 50))
        {
            throw new BadRequestException(
                "A language may contain at most 50 characters.");
        }
    }

    private static string? NormalizeNullableText(
        string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();
    }

    private static string? NormalizeLanguages(
        IEnumerable<string>? languages)
    {
        if (languages == null)
        {
            return null;
        }

        var normalizedLanguages =
            languages
                .Where(x =>
                    !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim())
                .Distinct(
                    StringComparer.OrdinalIgnoreCase)
                .OrderBy(x => x)
                .ToList();

        return normalizedLanguages.Count == 0
            ? null
            : string.Join(",", normalizedLanguages);
    }

    private static List<string> SplitLanguages(
        string? languages)
    {
        if (string.IsNullOrWhiteSpace(languages))
        {
            return [];
        }

        return languages
            .Split(
                ',',
                StringSplitOptions.RemoveEmptyEntries |
                StringSplitOptions.TrimEntries)
            .Distinct(
                StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static UserProfileDto MapToDto(
        ApplicationUser user,
        Client? client)
    {
        return new UserProfileDto
        {
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email ?? string.Empty,
            PhoneNumber =
                user.PhoneNumber ?? string.Empty,
            DateOfBirth = user.DateOfBirth,
            ProfileImageUrl =
                user.ProfileImageUrl,

            Location =
                client?.Location,

            PreferredTherapistGender =
                client?.PreferredTherapistGender,

            PreferredSessionType =
                client?.PreferredSessionType,

            MinimumPricePerSession =
                client?.MinimumPricePerSession,

            MaximumPricePerSession =
                client?.MaximumPricePerSession,

            PreferredLanguages =
                SplitLanguages(
                    client?.PreferredLanguages)
        };
    }
}