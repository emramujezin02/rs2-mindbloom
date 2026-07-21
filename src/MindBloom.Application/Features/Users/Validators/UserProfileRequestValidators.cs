using FluentValidation;
using MindBloom.Application.Features.Users.DTOs;

namespace MindBloom.Application.Features.Users.Validators;

public static class UserProfileValidationRules
{
    public const int MinimumNameLength = 2;
    public const int MaximumNameLength = 50;

    public const long MaximumProfileImageSize =
        5 * 1024 * 1024;

    public static readonly string[] AllowedImageExtensions =
    [
        ".jpg",
        ".jpeg",
        ".png"
    ];

    public static readonly string[] AllowedImageContentTypes =
    [
        "image/jpeg",
        "image/png"
    ];
}

public sealed class UpdateUserProfileDtoValidator
    : AbstractValidator<UpdateUserProfileDto>
{
    public UpdateUserProfileDtoValidator()
    {
        RuleFor(x => x.FirstName)
            .NotEmpty()
            .WithMessage(
                "First name is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "First name is required.")
            .MinimumLength(
                UserProfileValidationRules
                    .MinimumNameLength)
            .WithMessage(
                "First name must contain at least 2 characters.")
            .MaximumLength(
                UserProfileValidationRules
                    .MaximumNameLength)
            .WithMessage(
                "First name may contain at most 50 characters.");

        RuleFor(x => x.LastName)
            .NotEmpty()
            .WithMessage(
                "Last name is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Last name is required.")
            .MinimumLength(
                UserProfileValidationRules
                    .MinimumNameLength)
            .WithMessage(
                "Last name must contain at least 2 characters.")
            .MaximumLength(
                UserProfileValidationRules
                    .MaximumNameLength)
            .WithMessage(
                "Last name may contain at most 50 characters.");

        RuleFor(x => x.PhoneNumber)
            .Matches(
                @"^\+?[0-9][0-9\s\-]{6,19}$")
            .WithMessage(
                "Enter a valid phone number containing 7 to 20 characters. " +
                "Only digits, spaces, hyphens and an optional leading + are allowed.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.PhoneNumber));
    }
}

public sealed class UploadProfileImageDtoValidator
    : AbstractValidator<UploadProfileImageDto>
{
    public UploadProfileImageDtoValidator()
    {
        RuleFor(x => x.File)
            .NotNull()
            .WithMessage(
                "Select a profile image.");

        When(
            x => x.File != null,
            () =>
            {
                RuleFor(x => x.File.Length)
                    .GreaterThan(0)
                    .WithMessage(
                        "Select a profile image.")
                    .LessThanOrEqualTo(
                        UserProfileValidationRules
                            .MaximumProfileImageSize)
                    .WithMessage(
                        "Profile image may not exceed 5 MB.");

                RuleFor(x => x.File.FileName)
                    .Must(HaveAllowedExtension)
                    .WithMessage(
                        "Only JPG, JPEG and PNG images are allowed.");

                RuleFor(x => x.File.ContentType)
                    .Must(HaveAllowedContentType)
                    .WithMessage(
                        "The uploaded file has an unsupported content type.");
            });
    }

    private static bool HaveAllowedExtension(
        string fileName)
    {
        var extension =
            Path.GetExtension(fileName);

        return UserProfileValidationRules
            .AllowedImageExtensions
            .Contains(
                extension,
                StringComparer.OrdinalIgnoreCase);
    }

    private static bool HaveAllowedContentType(
        string contentType)
    {
        return UserProfileValidationRules
            .AllowedImageContentTypes
            .Contains(
                contentType,
                StringComparer.OrdinalIgnoreCase);
    }
}