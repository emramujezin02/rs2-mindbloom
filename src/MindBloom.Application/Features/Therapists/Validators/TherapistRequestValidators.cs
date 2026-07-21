using FluentValidation;
using Microsoft.AspNetCore.Http;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Therapists.Validators;

public static class TherapistValidationRules
{
    public const int MaximumSpecializationLength = 150;
    public const int MaximumBiographyLength = 2000;
    public const int MaximumLocationLength = 200;
    public const int MaximumCountryLength = 100;
    public const int MaximumCityLength = 100;
    public const int MaximumAddressLength = 250;
    public const int MaximumReasonLength = 500;
    public const int MaximumLanguageLength = 100;
    public const int MaximumSearchLength = 150;
    public const int MaximumPageSize = 100;
    public const int MaximumExperienceYears = 70;
    public const decimal MaximumHourlyRate = 10000;
    public const long MaximumDocumentSize = 10 * 1024 * 1024;

    public static readonly string[] AllowedSortFields =
    [
        "rating",
        "price",
        "experience"
    ];

    public static readonly string[] AllowedDocumentContentTypes =
    [
        "image/jpeg",
        "image/png",
        "application/pdf"
    ];

    public static IRuleBuilderOptions<T, string>
        RequiredText<T>(
            this IRuleBuilder<T, string> rule,
            string fieldName,
            int maximumLength)
    {
        return rule
            .NotEmpty()
            .WithMessage($"{fieldName} is required.")
            .MaximumLength(maximumLength)
            .WithMessage(
                $"{fieldName} may contain at most {maximumLength} characters.");
    }
}

public sealed class CreateTherapistDtoValidator
    : AbstractValidator<CreateTherapistDto>
{
    public CreateTherapistDtoValidator()
    {
        RuleFor(x => x.Specialization)
            .RequiredText(
                "Specialization",
                TherapistValidationRules
                    .MaximumSpecializationLength);

        RuleFor(x => x.Biography)
            .RequiredText(
                "Biography",
                TherapistValidationRules
                    .MaximumBiographyLength);

        RuleFor(x => x.HourlyRate)
            .GreaterThan(0)
            .WithMessage(
                "Hourly rate must be greater than zero.")
            .LessThanOrEqualTo(
                TherapistValidationRules
                    .MaximumHourlyRate)
            .WithMessage(
                $"Hourly rate may not exceed {TherapistValidationRules.MaximumHourlyRate}.");

        RuleFor(x => x.ExperienceYears)
            .InclusiveBetween(
                0,
                TherapistValidationRules
                    .MaximumExperienceYears)
            .WithMessage(
                $"Experience must be between 0 and {TherapistValidationRules.MaximumExperienceYears} years.");

        RuleFor(x => x.Country)
            .RequiredText(
                "Country",
                TherapistValidationRules
                    .MaximumCountryLength);

        RuleFor(x => x.City)
            .RequiredText(
                "City",
                TherapistValidationRules
                    .MaximumCityLength);

        RuleFor(x => x.Address)
            .RequiredText(
                "Address",
                TherapistValidationRules
                    .MaximumAddressLength);

        RuleFor(x => x)
            .Must(x =>
                x.OffersOnline ||
                x.OffersInPerson)
            .WithName("appointmentOptions")
            .WithMessage(
                "At least one appointment option must be enabled.");
    }
}

public sealed class CreateAvailabilityDtoValidator
    : AbstractValidator<CreateAvailabilityDto>
{
    public CreateAvailabilityDtoValidator()
    {
        RuleFor(x => x.DayOfWeek)
            .IsInEnum()
            .WithMessage(
                "Day of week is not valid.");

        RuleFor(x => x.StartTime)
            .GreaterThanOrEqualTo(
                TimeSpan.Zero)
            .WithMessage(
                "Start time is not valid.")
            .LessThan(
                TimeSpan.FromDays(1))
            .WithMessage(
                "Start time is not valid.");

        RuleFor(x => x.EndTime)
            .GreaterThan(
                TimeSpan.Zero)
            .WithMessage(
                "End time is not valid.")
            .LessThanOrEqualTo(
                TimeSpan.FromDays(1))
            .WithMessage(
                "End time is not valid.");

        RuleFor(x => x.EndTime)
            .GreaterThan(x =>
                x.StartTime)
            .WithMessage(
                "End time must be after start time.");
    }
}

public sealed class CreateUnavailableDateDtoValidator
    : AbstractValidator<CreateUnavailableDateDto>
{
    public CreateUnavailableDateDtoValidator()
    {
        RuleFor(x => x.StartUtc)
            .NotEmpty()
            .WithMessage(
                "Start date is required.");

        RuleFor(x => x.EndUtc)
            .NotEmpty()
            .WithMessage(
                "End date is required.")
            .GreaterThan(x =>
                x.StartUtc)
            .WithMessage(
                "End date must be after start date.");

        RuleFor(x => x.Reason)
            .RequiredText(
                "Reason",
                TherapistValidationRules
                    .MaximumReasonLength);
    }
}

public sealed class SearchTherapistsDtoValidator
    : AbstractValidator<SearchTherapistsDto>
{
    public SearchTherapistsDtoValidator()
    {
        RuleFor(x => x.Name)
            .MaximumLength(
                TherapistValidationRules
                    .MaximumSearchLength)
            .WithMessage(
                $"Name search may contain at most {TherapistValidationRules.MaximumSearchLength} characters.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Name));

        RuleFor(x => x.Specialization)
            .MaximumLength(
                TherapistValidationRules
                    .MaximumSpecializationLength)
            .WithMessage(
                $"Specialization may contain at most {TherapistValidationRules.MaximumSpecializationLength} characters.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Specialization));

        RuleFor(x => x.PageNumber)
            .GreaterThanOrEqualTo(1)
            .WithMessage(
                "Page number must be at least 1.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(
                1,
                TherapistValidationRules
                    .MaximumPageSize)
            .WithMessage(
                $"Page size must be between 1 and {TherapistValidationRules.MaximumPageSize}.");

        RuleFor(x => x.SortBy)
            .Must(sortBy =>
                string.IsNullOrWhiteSpace(sortBy) ||
                TherapistValidationRules
                    .AllowedSortFields
                    .Contains(
                        sortBy.Trim()
                            .ToLowerInvariant()))
            .WithMessage(
                "Sort field must be rating, price or experience.");
    }
}

public sealed class TherapistFilterDtoValidator
    : AbstractValidator<TherapistFilterDto>
{
    public TherapistFilterDtoValidator()
    {
        RuleFor(x => x.Specialization)
            .MaximumLength(
                TherapistValidationRules
                    .MaximumSpecializationLength)
            .WithMessage(
                $"Specialization may contain at most {TherapistValidationRules.MaximumSpecializationLength} characters.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Specialization));

        RuleFor(x => x.MinPrice)
            .GreaterThanOrEqualTo(0)
            .WithMessage(
                "Minimum price cannot be negative.")
            .LessThanOrEqualTo(
                TherapistValidationRules
                    .MaximumHourlyRate)
            .WithMessage(
                $"Minimum price may not exceed {TherapistValidationRules.MaximumHourlyRate}.")
            .When(x =>
                x.MinPrice.HasValue);

        RuleFor(x => x.MaxPrice)
            .GreaterThanOrEqualTo(0)
            .WithMessage(
                "Maximum price cannot be negative.")
            .LessThanOrEqualTo(
                TherapistValidationRules
                    .MaximumHourlyRate)
            .WithMessage(
                $"Maximum price may not exceed {TherapistValidationRules.MaximumHourlyRate}.")
            .When(x =>
                x.MaxPrice.HasValue);

        RuleFor(x => x.MaxPrice)
            .GreaterThanOrEqualTo(x =>
                x.MinPrice)
            .WithMessage(
                "Maximum price must be greater than or equal to minimum price.")
            .When(x =>
                x.MinPrice.HasValue &&
                x.MaxPrice.HasValue);
    }
}


