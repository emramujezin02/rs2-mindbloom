using FluentValidation;
using MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;

namespace MindBloom.Application.Features
    .PrivateJournalEntries.Validators;

public static class PrivateJournalEntryValidationRules
{
    public const int MinimumTitleLength = 1;

    public const int MaximumTitleLength = 150;

    public const int MinimumContentLength = 1;

    public const int MaximumContentLength = 10000;

    public const int MaximumSearchLength = 150;

    public const int MaximumPageSize = 50;
}

public sealed class CreatePrivateJournalEntryDtoValidator
    : AbstractValidator<CreatePrivateJournalEntryDto>
{
    public CreatePrivateJournalEntryDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .WithMessage(
                "Title is required.")
            .MinimumLength(
                PrivateJournalEntryValidationRules
                    .MinimumTitleLength)
            .MaximumLength(
                PrivateJournalEntryValidationRules
                    .MaximumTitleLength)
            .WithMessage(
                "Title may contain at most 150 characters.");

        RuleFor(x => x.Content)
            .NotEmpty()
            .WithMessage(
                "Journal content is required.")
            .MinimumLength(
                PrivateJournalEntryValidationRules
                    .MinimumContentLength)
            .MaximumLength(
                PrivateJournalEntryValidationRules
                    .MaximumContentLength)
            .WithMessage(
                "Journal content may contain at most 10000 characters.");

        RuleFor(x => x.EntryDateUtc)
            .NotEmpty()
            .WithMessage(
                "Entry date is required.")
            .Must(date =>
                date <= DateTime.UtcNow.AddMinutes(5))
            .WithMessage(
                "Entry date cannot be in the future.");

        RuleFor(x => x.MoodEntryId)
            .GreaterThan(0)
            .When(x =>
                x.MoodEntryId.HasValue)
            .WithMessage(
                "Mood entry identifier must be greater than zero.");
    }
}

public sealed class UpdatePrivateJournalEntryDtoValidator
    : AbstractValidator<UpdatePrivateJournalEntryDto>
{
    public UpdatePrivateJournalEntryDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .WithMessage(
                "Title is required.")
            .MinimumLength(
                PrivateJournalEntryValidationRules
                    .MinimumTitleLength)
            .MaximumLength(
                PrivateJournalEntryValidationRules
                    .MaximumTitleLength)
            .WithMessage(
                "Title may contain at most 150 characters.");

        RuleFor(x => x.Content)
            .NotEmpty()
            .WithMessage(
                "Journal content is required.")
            .MinimumLength(
                PrivateJournalEntryValidationRules
                    .MinimumContentLength)
            .MaximumLength(
                PrivateJournalEntryValidationRules
                    .MaximumContentLength)
            .WithMessage(
                "Journal content may contain at most 10000 characters.");

        RuleFor(x => x.EntryDateUtc)
            .NotEmpty()
            .WithMessage(
                "Entry date is required.")
            .Must(date =>
                date <= DateTime.UtcNow.AddMinutes(5))
            .WithMessage(
                "Entry date cannot be in the future.");

        RuleFor(x => x.MoodEntryId)
            .GreaterThan(0)
            .When(x =>
                x.MoodEntryId.HasValue)
            .WithMessage(
                "Mood entry identifier must be greater than zero.");
    }
}

public sealed class PrivateJournalEntryQueryDtoValidator
    : AbstractValidator<PrivateJournalEntryQueryDto>
{
    public PrivateJournalEntryQueryDtoValidator()
    {
        RuleFor(x => x.PageNumber)
            .GreaterThan(0)
            .WithMessage(
                "Page number must be greater than zero.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(
                1,
                PrivateJournalEntryValidationRules
                    .MaximumPageSize)
            .WithMessage(
                "Page size must be between 1 and 50.");

        RuleFor(x => x.Search)
            .MaximumLength(
                PrivateJournalEntryValidationRules
                    .MaximumSearchLength)
            .WithMessage(
                "Search may contain at most 150 characters.");

        RuleFor(x => x)
            .Must(query =>
                !query.FromUtc.HasValue ||
                !query.ToUtc.HasValue ||
                query.FromUtc.Value <=
                    query.ToUtc.Value)
            .WithMessage(
                "Start date cannot be later than end date.");
    }
}