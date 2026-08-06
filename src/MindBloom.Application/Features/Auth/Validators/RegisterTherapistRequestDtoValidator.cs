using FluentValidation;
using MindBloom.Application.Features.Auth.DTOs;

namespace MindBloom.Application.Features.Auth.Validators;

public sealed class RegisterTherapistRequestDtoValidator
    : AbstractValidator<RegisterTherapistRequestDto>
{
    public RegisterTherapistRequestDtoValidator()
    {
        RuleFor(x => x.FirstName)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.LastName)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(256);

        RuleFor(x => x.Username)
            .NotEmpty()
            .MinimumLength(3)
            .MaximumLength(100);

        RuleFor(x => x.Password)
            .NotEmpty()
            .MinimumLength(
                AuthValidationRules
                    .MinimumPasswordLength)
            .Matches("[A-Z]")
            .WithMessage(
                "Password must contain at least one uppercase letter.")
            .Matches("[a-z]")
            .WithMessage(
                "Password must contain at least one lowercase letter.")
            .Matches("[0-9]")
            .WithMessage(
                "Password must contain at least one number.")
            .Matches("[^a-zA-Z0-9]")
            .WithMessage(
                "Password must contain at least one special character.");

        RuleFor(x => x.DateOfBirth)
            .NotEmpty()
            .Must(date =>
                date.Date <
                DateTime.UtcNow.Date)
            .WithMessage(
                "Date of birth must be in the past.");

        RuleFor(x => x.Gender)
            .NotEmpty()
            .Must(value =>
            {
                if (string.IsNullOrWhiteSpace(
                        value))
                {
                    return false;
                }

                var normalized =
                    value.Trim();

                return normalized.Equals(
                           "Male",
                           StringComparison
                               .OrdinalIgnoreCase)
                       ||
                       normalized.Equals(
                           "Female",
                           StringComparison
                               .OrdinalIgnoreCase)
                       ||
                       normalized.Equals(
                           "Other",
                           StringComparison
                               .OrdinalIgnoreCase);
            })
            .WithMessage(
                "Gender must be Male, Female or Other.");

        RuleFor(x => x.Specialization)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(x => x.Biography)
            .NotEmpty()
            .MaximumLength(3000);

        RuleFor(x => x.HourlyRate)
            .GreaterThan(0);

        RuleFor(x => x.ExperienceYears)
            .InclusiveBetween(
                0,
                70);

        RuleFor(x => x.Country)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.City)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.Address)
            .NotEmpty()
            .MaximumLength(300);

        RuleFor(x => x)
            .Must(x =>
                x.OffersOnline ||
                x.OffersInPerson)
            .WithMessage(
                "Therapist must offer at least one session type.");
    }
}