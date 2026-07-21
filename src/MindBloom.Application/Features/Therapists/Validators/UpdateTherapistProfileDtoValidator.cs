using FluentValidation;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Therapists.Validators;

public sealed class UpdateTherapistProfileDtoValidator
    : AbstractValidator<UpdateTherapistProfileDto>
{
    public UpdateTherapistProfileDtoValidator()
    {
        RuleFor(x => x.Biography)
            .NotEmpty()
            .WithMessage("Biography is required.")
            .MaximumLength(2000)
            .WithMessage("Biography cannot contain more than 2000 characters.");

        RuleFor(x => x.Specialization)
            .NotEmpty()
            .WithMessage("Specialization is required.")
            .MaximumLength(200)
            .WithMessage("Specialization cannot contain more than 200 characters.");

        RuleFor(x => x.ExperienceYears)
            .InclusiveBetween(0, 70)
            .WithMessage("Experience must be between 0 and 70 years.");

        RuleFor(x => x.HourlyRate)
            .GreaterThan(0)
            .WithMessage("Hourly rate must be greater than zero.")
            .LessThanOrEqualTo(10000)
            .WithMessage("Hourly rate cannot be greater than 10000.");

        RuleFor(x => x.Location)
            .NotEmpty()
            .WithMessage("Location is required.")
            .MaximumLength(200)
            .WithMessage("Location cannot contain more than 200 characters.");

        RuleFor(x => x.Country)
            .NotEmpty()
            .WithMessage("Country is required.")
            .MaximumLength(100)
            .WithMessage("Country cannot contain more than 100 characters.");

        RuleFor(x => x.City)
            .NotEmpty()
            .WithMessage("City is required.")
            .MaximumLength(100)
            .WithMessage("City cannot contain more than 100 characters.");

        RuleFor(x => x.Address)
            .MaximumLength(250)
            .WithMessage("Address cannot contain more than 250 characters.");

        RuleFor(x => x.Address)
            .NotEmpty()
            .When(x => x.OffersInPerson)
            .WithMessage("Address is required when in-person appointments are offered.");

        RuleFor(x => x.Languages)
            .NotNull()
            .WithMessage("Languages are required.")
            .Must(x => x!.Count > 0)
            .WithMessage("At least one language is required.")
            .Must(x => x!.Count <= 20)
            .WithMessage("A maximum of 20 languages may be selected.");

        RuleForEach(x => x.Languages)
            .NotEmpty()
            .WithMessage("Language cannot be empty.")
            .MaximumLength(100)
            .WithMessage("Language cannot contain more than 100 characters.");

        RuleFor(x => x)
            .Must(x => x.OffersOnline || x.OffersInPerson)
            .WithMessage("The therapist must offer online or in-person appointments.");
    }
}

public sealed class UploadTherapistProfileImageDtoValidator
    : AbstractValidator<UploadTherapistProfileImageDto>
{
    private const long MaximumFileSize =
        5 * 1024 * 1024;

    private static readonly string[] AllowedContentTypes =
    [
        "image/jpeg",
        "image/png",
        "image/webp"
    ];

    private static readonly string[] AllowedExtensions =
    [
        ".jpg",
        ".jpeg",
        ".png",
        ".webp"
    ];

    public UploadTherapistProfileImageDtoValidator()
    {
        RuleFor(x => x.File)
            .NotNull()
            .WithMessage("Profile image is required.");

        When(x => x.File != null, () =>
        {
            RuleFor(x => x.File.Length)
                .GreaterThan(0)
                .WithMessage("Profile image is required.")
                .LessThanOrEqualTo(MaximumFileSize)
                .WithMessage("Profile image cannot be larger than 5 MB.");

            RuleFor(x => x.File.ContentType)
                .Must(x => AllowedContentTypes.Contains(
                    x,
                    StringComparer.OrdinalIgnoreCase))
                .WithMessage("Only JPG, PNG and WEBP images are allowed.");

            RuleFor(x => x.File.FileName)
                .Must(fileName =>
                {
                    var extension =
                        Path.GetExtension(fileName);

                    return AllowedExtensions.Contains(
                        extension,
                        StringComparer.OrdinalIgnoreCase);
                })
                .WithMessage("Unsupported profile image extension.");
        });
    }
}

public sealed class UploadTherapistDocumentDtoValidator
    : AbstractValidator<UploadTherapistDocumentDto>
{
    private const long MaximumDocumentSize =
        10 * 1024 * 1024;

    private static readonly string[] AllowedContentTypes =
    [
        "image/jpeg",
        "image/png",
        "application/pdf"
    ];

    public UploadTherapistDocumentDtoValidator()
    {
        RuleFor(x => x.File)
            .NotNull()
            .WithMessage("Document is required.");

        When(x => x.File != null, () =>
        {
            RuleFor(x => x.File.Length)
                .GreaterThan(0)
                .WithMessage("Document is required.")
                .LessThanOrEqualTo(MaximumDocumentSize)
                .WithMessage("Document cannot be larger than 10 MB.");

            RuleFor(x => x.File.ContentType)
                .Must(x => AllowedContentTypes.Contains(
                    x,
                    StringComparer.OrdinalIgnoreCase))
                .WithMessage("Only JPG, PNG and PDF files are allowed.");
        });
    }
}