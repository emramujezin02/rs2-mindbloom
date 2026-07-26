using FluentValidation;
using MindBloom.Application
    .Features.ClientOnboarding.DTOs;

namespace MindBloom.Application
    .Features.ClientOnboarding.Validators;

public sealed class SaveClientOnboardingDtoValidator
    : AbstractValidator<SaveClientOnboardingDto>
{
    private static readonly HashSet<string>
        AllowedGenders =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "Any",
            "Female",
            "Male"
        };

    private static readonly HashSet<string>
        AllowedSessionTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "Any",
            "Online",
            "InPerson"
        };

    public SaveClientOnboardingDtoValidator()
    {
        RuleFor(x => x.AssessmentFocusAreas)
            .NotNull()
            .WithMessage(
                "Assessment focus areas are required.")
            .Must(x =>
                x.Count > 0)
            .WithMessage(
                "Select at least one area you would like support with.")
            .Must(x =>
                x.Count <= 10)
            .WithMessage(
                "You may select at most 10 focus areas.");

        RuleForEach(x =>
                x.AssessmentFocusAreas)
            .Must(x =>
                !string.IsNullOrWhiteSpace(x))
            .WithMessage(
                "Focus areas may not be empty.")
            .MaximumLength(100)
            .WithMessage(
                "Each focus area may contain at most 100 characters.");

        RuleFor(x =>
                x.PreferredTherapistGender)
            .Must(value =>
                string.IsNullOrWhiteSpace(value) ||
                AllowedGenders.Contains(
                    value.Trim()))
            .WithMessage(
                "Preferred therapist gender must be Any, Female or Male.");

        RuleFor(x =>
                x.PreferredSessionType)
            .Must(value =>
                string.IsNullOrWhiteSpace(value) ||
                AllowedSessionTypes.Contains(
                    value.Trim()))
            .WithMessage(
                "Preferred session type must be Any, Online or InPerson.");

        RuleFor(x => x.PreferredLanguages)
            .NotNull()
            .WithMessage(
                "Preferred languages are required.")
            .Must(x =>
                x.Count > 0)
            .WithMessage(
                "Select at least one preferred language.")
            .Must(x =>
                x.Count <= 10)
            .WithMessage(
                "You may select at most 10 preferred languages.");

        RuleForEach(x =>
                x.PreferredLanguages)
            .Must(x =>
                !string.IsNullOrWhiteSpace(x))
            .WithMessage(
                "Preferred languages may not be empty.")
            .MaximumLength(50)
            .WithMessage(
                "Each language may contain at most 50 characters.");

        RuleFor(x =>
                x.MinimumPricePerSession)
            .GreaterThanOrEqualTo(0)
            .When(x =>
                x.MinimumPricePerSession
                    .HasValue)
            .WithMessage(
                "Minimum price cannot be negative.");

        RuleFor(x =>
                x.MaximumPricePerSession)
            .GreaterThanOrEqualTo(0)
            .When(x =>
                x.MaximumPricePerSession
                    .HasValue)
            .WithMessage(
                "Maximum price cannot be negative.");

        RuleFor(x => x)
            .Must(x =>
                !x.MinimumPricePerSession
                    .HasValue ||
                !x.MaximumPricePerSession
                    .HasValue ||
                x.MinimumPricePerSession.Value <=
                x.MaximumPricePerSession.Value)
            .WithMessage(
                "Minimum price cannot be greater than maximum price.");

        RuleFor(x => x.Location)
            .MaximumLength(200)
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Location))
            .WithMessage(
                "Location may contain at most 200 characters.");

        RuleFor(x =>
                x.PreferredTherapyApproachIds)
            .NotNull()
            .WithMessage(
                "Therapy approaches are required.")
            .Must(x =>
                x.Count > 0)
            .WithMessage(
                "Select at least one therapy approach.")
            .Must(x =>
                x.Count <= 10)
            .WithMessage(
                "You may select at most 10 therapy approaches.");

        RuleForEach(x =>
                x.PreferredTherapyApproachIds)
            .GreaterThan(0)
            .WithMessage(
                "Therapy approach identifier is invalid.");

        RuleFor(x => x.PreferredDays)
            .NotNull()
            .WithMessage(
                "Preferred days are required.")
            .Must(x =>
                x.Count <= 7)
            .WithMessage(
                "You may select at most seven preferred days.");
    }
}