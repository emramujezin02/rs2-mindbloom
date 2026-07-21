using FluentValidation;
using MindBloom.Application.Features.Reviews.DTOs;

namespace MindBloom.Application.Features.Reviews.Validators;

public static class ReviewValidationRules
{
    public const int MinimumRating = 1;
    public const int MaximumRating = 5;
    public const int MaximumCommentLength = 1000;
    public const int MaximumReplyLength = 1000;
}

public sealed class CreateReviewDtoValidator
    : AbstractValidator<CreateReviewDto>
{
    public CreateReviewDtoValidator()
    {
        RuleFor(x => x.AppointmentId)
            .GreaterThan(0)
            .WithMessage(
                "Appointment identifier must be greater than zero.");

        RuleFor(x => x.Rating)
            .InclusiveBetween(
                ReviewValidationRules.MinimumRating,
                ReviewValidationRules.MaximumRating)
            .WithMessage(
                $"Rating must be between {ReviewValidationRules.MinimumRating} and {ReviewValidationRules.MaximumRating}.");

        RuleFor(x => x.Comment)
            .NotEmpty()
            .WithMessage(
                "Review comment is required.")
            .MaximumLength(
                ReviewValidationRules
                    .MaximumCommentLength)
            .WithMessage(
                $"Review comment may contain at most {ReviewValidationRules.MaximumCommentLength} characters.");
    }
}

public sealed class UpdateReviewDtoValidator
    : AbstractValidator<UpdateReviewDto>
{
    public UpdateReviewDtoValidator()
    {
        RuleFor(x => x.Rating)
            .InclusiveBetween(
                ReviewValidationRules.MinimumRating,
                ReviewValidationRules.MaximumRating)
            .WithMessage(
                $"Rating must be between {ReviewValidationRules.MinimumRating} and {ReviewValidationRules.MaximumRating}.");

        RuleFor(x => x.Comment)
            .NotEmpty()
            .WithMessage(
                "Review comment is required.")
            .MaximumLength(
                ReviewValidationRules
                    .MaximumCommentLength)
            .WithMessage(
                $"Review comment may contain at most {ReviewValidationRules.MaximumCommentLength} characters.");
    }
}

public sealed class ReplyToReviewDtoValidator
    : AbstractValidator<ReplyToReviewDto>
{
    public ReplyToReviewDtoValidator()
    {
        RuleFor(x => x.Reply)
            .NotEmpty()
            .WithMessage(
                "Review reply is required.")
            .MaximumLength(
                ReviewValidationRules
                    .MaximumReplyLength)
            .WithMessage(
                $"Review reply may contain at most {ReviewValidationRules.MaximumReplyLength} characters.");
    }
}

public sealed class ReviewFilterDtoValidator
    : AbstractValidator<ReviewFilterDto>
{
    public ReviewFilterDtoValidator()
    {
        RuleFor(x => x.SortBy)
            .IsInEnum()
            .WithMessage(
                "Review sorting option is not valid.");
    }
}