using FluentValidation;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Therapists.Validators;

public class UpdateTherapistProfileDtoValidator
    : AbstractValidator<UpdateTherapistProfileDto>
{
    public UpdateTherapistProfileDtoValidator()
    {
        RuleFor(x => x.Biography)
            .NotEmpty()
            .WithMessage("Biography is required.")
            .MaximumLength(2000)
            .WithMessage(
                "Biography cannot contain more than 2000 characters.");

        RuleFor(x => x.Specialization)
            .NotEmpty()
            .WithMessage("Specialization is required.")
            .MaximumLength(200)
            .WithMessage(
                "Specialization cannot contain more than 200 characters.");

        RuleFor(x => x.ExperienceYears)
            .GreaterThanOrEqualTo(0)
            .WithMessage(
                "Experience cannot be negative.")
            .LessThanOrEqualTo(70)
            .WithMessage(
                "Experience cannot be greater than 70 years.");

        RuleFor(x => x.HourlyRate)
            .GreaterThan(0)
            .WithMessage(
                "Hourly rate must be greater than zero.")
            .LessThanOrEqualTo(10000)
            .WithMessage(
                "Hourly rate cannot be greater than 10000.");

        RuleFor(x => x.Location)
            .NotEmpty()
            .WithMessage("Location is required.")
            .MaximumLength(200)
            .WithMessage(
                "Location cannot contain more than 200 characters.");

        RuleFor(x => x.Languages)
            .NotEmpty()
            .WithMessage(
                "At least one language is required.");

        RuleForEach(x => x.Languages)
            .NotEmpty()
            .WithMessage(
                "Language cannot be empty.")
            .MaximumLength(100)
            .WithMessage(
                "Language cannot contain more than 100 characters.");

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

        RuleFor(x => x)
            .Must(x => x.OffersOnline || x.OffersInPerson)
            .WithMessage(
                "The therapist must offer online or in-person appointments.");


            RuleFor(x => x.Address)
    .NotEmpty()
    .When(x => x.OffersInPerson)
    .WithMessage(
        "Address is required when in-person appointments are offered.");

    }
}