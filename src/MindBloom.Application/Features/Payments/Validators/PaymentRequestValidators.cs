using FluentValidation;
using MindBloom.Application.Features.Payments.DTOs;

namespace MindBloom.Application.Features.Payments.Validators;

public static class PaymentValidationRules
{
    public const int MaximumPaymentIntentIdLength =
        255;
}

public sealed class CreatePaymentIntentDtoValidator
    : AbstractValidator<CreatePaymentIntentDto>
{
    public CreatePaymentIntentDtoValidator()
    {
        RuleFor(x => x.AppointmentId)
            .GreaterThan(0)
            .WithMessage(
                "Appointment identifier must be greater than zero.");
    }
}

public sealed class ConfirmPaymentDtoValidator
    : AbstractValidator<ConfirmPaymentDto>
{
    public ConfirmPaymentDtoValidator()
    {
        RuleFor(x => x.PaymentIntentId)
            .NotEmpty()
            .WithMessage(
                "Payment intent ID is required.")
            .MaximumLength(
                PaymentValidationRules
                    .MaximumPaymentIntentIdLength)
            .WithMessage(
                $"Payment intent ID may contain at most {PaymentValidationRules.MaximumPaymentIntentIdLength} characters.")
            .Matches(@"^pi_[a-zA-Z0-9_]+$")
            .WithMessage(
                "Payment intent ID has an invalid format.");
    }
}