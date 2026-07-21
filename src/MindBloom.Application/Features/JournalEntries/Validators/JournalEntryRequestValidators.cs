using FluentValidation;
using MindBloom.Application.Features
    .JournalEntries.DTOs;

namespace MindBloom.Application.Features
    .JournalEntries.Validators;

public static class JournalEntryValidationRules
{
    public const int MinimumMood = 1;
    public const int MaximumMood = 5;

    public const int MaximumEmotionLength = 100;
    public const int MaximumNoteLength = 2000;

    public const int MaximumPageSize = 50;

    public static readonly int[] AllowedTrendPeriods =
    [
        7,
        14,
        30,
        90,
        180,
        365
    ];
}

public sealed class CreateJournalEntryDtoValidator
    : AbstractValidator<CreateJournalEntryDto>
{
    public CreateJournalEntryDtoValidator()
    {
        RuleFor(x => x.Mood)
            .InclusiveBetween(
                JournalEntryValidationRules.MinimumMood,
                JournalEntryValidationRules.MaximumMood)
            .WithMessage(
                "Mood must be between 1 and 5.");

        RuleFor(x => x.Emotion)
            .NotEmpty()
            .WithMessage(
                "Emotion is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Emotion is required.")
            .MaximumLength(
                JournalEntryValidationRules
                    .MaximumEmotionLength)
            .WithMessage(
                "Emotion may contain at most 100 characters.");

        RuleFor(x => x.Note)
            .MaximumLength(
                JournalEntryValidationRules
                    .MaximumNoteLength)
            .WithMessage(
                "Note may contain at most 2000 characters.");
    }
}

public sealed class UpdateJournalEntryDtoValidator
    : AbstractValidator<UpdateJournalEntryDto>
{
    public UpdateJournalEntryDtoValidator()
    {
        RuleFor(x => x.Mood)
            .InclusiveBetween(
                JournalEntryValidationRules.MinimumMood,
                JournalEntryValidationRules.MaximumMood)
            .WithMessage(
                "Mood must be between 1 and 5.");

        RuleFor(x => x.Emotion)
            .NotEmpty()
            .WithMessage(
                "Emotion is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Emotion is required.")
            .MaximumLength(
                JournalEntryValidationRules
                    .MaximumEmotionLength)
            .WithMessage(
                "Emotion may contain at most 100 characters.");

        RuleFor(x => x.Note)
            .MaximumLength(
                JournalEntryValidationRules
                    .MaximumNoteLength)
            .WithMessage(
                "Note may contain at most 2000 characters.");
    }
}

public sealed class JournalEntryPagingQueryDtoValidator
    : AbstractValidator<JournalEntryPagingQueryDto>
{
    public JournalEntryPagingQueryDtoValidator()
    {
        RuleFor(x => x.PageNumber)
            .GreaterThan(0)
            .WithMessage(
                "Page number must be greater than zero.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(
                1,
                JournalEntryValidationRules
                    .MaximumPageSize)
            .WithMessage(
                "Page size must be between 1 and 50.");
    }
}

public sealed class JournalEntryTrendQueryDtoValidator
    : AbstractValidator<JournalEntryTrendQueryDto>
{
    public JournalEntryTrendQueryDtoValidator()
    {
        RuleFor(x => x.Days)
            .Must(days =>
                JournalEntryValidationRules
                    .AllowedTrendPeriods
                    .Contains(days))
            .WithMessage(
                "Days must be one of the following values: 7, 14, 30, 90, 180 or 365.");
    }
}