using FluentValidation;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Memberships.Validators;

public static class MembershipValidationRules
{
    public const int MaximumPaymentIntentIdLength =
        255;

    public static bool IsSupportedPlan(
        MembershipPlanType planType)
    {
        return planType is
            MembershipPlanType.TenSessions or
            MembershipPlanType.TwentySessions or
            MembershipPlanType.ThirtySessions;
    }
}

public sealed class
    CreateMembershipPaymentIntentDtoValidator
    : AbstractValidator<
        CreateMembershipPaymentIntentDto>
{
    public CreateMembershipPaymentIntentDtoValidator()
    {
        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .WithMessage(
                "Therapist identifier must be greater than zero.");

        RuleFor(x => x.PlanType)
            .IsInEnum()
            .WithMessage(
                "Membership plan type is not valid.");

        RuleFor(x => x.PlanType)
            .Must(
                MembershipValidationRules
                    .IsSupportedPlan)
            .WithMessage(
                "Selected membership plan is not supported.");
    }
}

public sealed class
    ConfirmMembershipPaymentDtoValidator
    : AbstractValidator<
        ConfirmMembershipPaymentDto>
{
    public ConfirmMembershipPaymentDtoValidator()
    {
        RuleFor(x => x.PaymentIntentId)
            .NotEmpty()
            .WithMessage(
                "Payment intent ID is required.")
            .MaximumLength(
                MembershipValidationRules
                    .MaximumPaymentIntentIdLength)
            .WithMessage(
                $"Payment intent ID may contain at most {MembershipValidationRules.MaximumPaymentIntentIdLength} characters.")
            .Matches(@"^pi_[a-zA-Z0-9_]+$")
            .WithMessage(
                "Payment intent ID has an invalid format.");
    }
}

public sealed class UseMembershipDtoValidator
    : AbstractValidator<UseMembershipDto>
{
    public UseMembershipDtoValidator()
    {
        RuleFor(x => x.AppointmentId)
            .GreaterThan(0)
            .WithMessage(
                "Appointment identifier must be greater than zero.");
    }
}

public sealed class PurchaseMembershipDtoValidator
    : AbstractValidator<PurchaseMembershipDto>
{
    public PurchaseMembershipDtoValidator()
    {
        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .WithMessage(
                "Therapist identifier must be greater than zero.");

        RuleFor(x => x.PlanType)
            .IsInEnum()
            .WithMessage(
                "Membership plan type is not valid.");

        RuleFor(x => x.PlanType)
            .Must(
                MembershipValidationRules
                    .IsSupportedPlan)
            .WithMessage(
                "Selected membership plan is not supported.");
    }
}