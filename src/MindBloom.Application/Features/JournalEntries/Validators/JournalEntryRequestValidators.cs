using FluentValidation;
using MindBloom.Application.Features.JournalEntries.DTOs;

namespace MindBloom.Application.Features.JournalEntries.Validators;

public static class JournalEntryValidationRules
{
    public const int MinimumMood = 1;
    public const int MaximumMood = 5;

    public const int MinimumEmotionCount = 1;
    public const int MaximumEmotionCount = 5;
    public const int MaximumEmotionLength = 50;
    public const int MaximumNoteLength = 500;

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

        RuleFor(x => x.Emotions)
            .NotNull()
            .WithMessage(
                "At least one emotion must be selected.")
            .Must(emotions =>
                emotions != null &&
                emotions.Count >=
                JournalEntryValidationRules.MinimumEmotionCount)
            .WithMessage(
                "At least one emotion must be selected.")
            .Must(emotions =>
                emotions == null ||
                emotions.Count <=
                JournalEntryValidationRules.MaximumEmotionCount)
            .WithMessage(
                "You may select at most 5 emotions.");

        RuleForEach(x => x.Emotions)
            .NotEmpty()
            .WithMessage(
                "Emotion cannot be empty.")
            .MaximumLength(
                JournalEntryValidationRules.MaximumEmotionLength)
            .WithMessage(
                "Each emotion may contain at most 50 characters.");

        RuleFor(x => x.Note)
            .MaximumLength(
                JournalEntryValidationRules.MaximumNoteLength)
            .WithMessage(
                "Note may contain at most 500 characters.");
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

        RuleFor(x => x.Emotions)
            .NotNull()
            .WithMessage(
                "At least one emotion must be selected.")
            .Must(emotions =>
                emotions != null &&
                emotions.Count >=
                JournalEntryValidationRules.MinimumEmotionCount)
            .WithMessage(
                "At least one emotion must be selected.")
            .Must(emotions =>
                emotions == null ||
                emotions.Count <=
                JournalEntryValidationRules.MaximumEmotionCount)
            .WithMessage(
                "You may select at most 5 emotions.");

        RuleForEach(x => x.Emotions)
            .NotEmpty()
            .WithMessage(
                "Emotion cannot be empty.")
            .MaximumLength(
                JournalEntryValidationRules.MaximumEmotionLength)
            .WithMessage(
                "Each emotion may contain at most 50 characters.");

        RuleFor(x => x.Note)
            .MaximumLength(
                JournalEntryValidationRules.MaximumNoteLength)
            .WithMessage(
                "Note may contain at most 500 characters.");
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
                JournalEntryValidationRules.MaximumPageSize)
            .WithMessage(
                "Page size must be between 1 and 50.");

        RuleFor(x => x)
            .Must(query =>
                !query.FromUtc.HasValue ||
                !query.ToUtc.HasValue ||
                query.FromUtc.Value <= query.ToUtc.Value)
            .WithMessage(
                "Start date cannot be later than end date.");
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