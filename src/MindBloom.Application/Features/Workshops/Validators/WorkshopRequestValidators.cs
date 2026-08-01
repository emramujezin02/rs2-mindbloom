using FluentValidation;
using MindBloom.Application.Features.Workshops.DTOs;
using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Workshops.Validators;

public static class WorkshopValidationRules
{
    public const int MinTitleLength = 3;
    public const int MaxTitleLength = 150;

    public const int MinDescriptionLength = 10;
    public const int MaxDescriptionLength = 2000;

    public const int MinCapacity = 1;
    public const int MaxCapacity = 10000;

    public const int MaximumImageUrlLength = 1000;
}

public sealed class CreateWorkshopDtoValidator
    : AbstractValidator<CreateWorkshopDto>
{
    public CreateWorkshopDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .MinimumLength(WorkshopValidationRules.MinTitleLength)
            .MaximumLength(WorkshopValidationRules.MaxTitleLength);

        RuleFor(x => x.Description)
            .NotEmpty()
            .MinimumLength(WorkshopValidationRules.MinDescriptionLength)
            .MaximumLength(WorkshopValidationRules.MaxDescriptionLength);

        RuleFor(x => x.StartUtc)
            .GreaterThan(DateTime.UtcNow)
            .WithMessage("Workshop must be scheduled in the future.");

        RuleFor(x => x.EndUtc)
            .GreaterThan(x => x.StartUtc)
            .WithMessage("Workshop end time must be after its start time.");

        RuleFor(x => x.Type)
            .IsInEnum();

        RuleFor(x => x.Capacity)
            .InclusiveBetween(
                WorkshopValidationRules.MinCapacity,
                WorkshopValidationRules.MaxCapacity);

        RuleFor(x => x.Price)
            .GreaterThanOrEqualTo(0);

        RuleFor(x => x.RegistrationDeadlineUtc)
    .GreaterThan(DateTime.UtcNow)
    .WithMessage(
        "Registration deadline must be in the future.");

        RuleFor(x => x.RegistrationDeadlineUtc)
            .LessThanOrEqualTo(x => x.StartUtc)
            .WithMessage(
                "Registration deadline must be before or equal to workshop start time.");

        RuleFor(x => x.ImageUrl)
    .MaximumLength(
        WorkshopValidationRules
            .MaximumImageUrlLength)
    .WithMessage(
        "Image URL may contain at most 1000 characters.")
    .When(x =>
        !string.IsNullOrWhiteSpace(
            x.ImageUrl));

        When(x => x.Type == WorkshopType.Online, () =>
        {
            RuleFor(x => x.OnlineLink)
                .NotEmpty()
                .Must(url =>
                    Uri.TryCreate(
                        url,
                        UriKind.Absolute,
                        out var uri)
                    && (uri.Scheme == Uri.UriSchemeHttp
                        || uri.Scheme == Uri.UriSchemeHttps))
                .WithMessage(
                    "Online link must be a valid HTTP or HTTPS URL.");
        });

        When(x => x.Type == WorkshopType.InPerson, () =>
        {
            RuleFor(x => x.Location)
                .NotEmpty()
                .MaximumLength(300);
        });

        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .When(x => x.TherapistId.HasValue);
    }
}

public sealed class UpdateWorkshopDtoValidator
    : AbstractValidator<UpdateWorkshopDto>
{
    public UpdateWorkshopDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .MinimumLength(WorkshopValidationRules.MinTitleLength)
            .MaximumLength(WorkshopValidationRules.MaxTitleLength);

        RuleFor(x => x.Description)
            .NotEmpty()
            .MinimumLength(WorkshopValidationRules.MinDescriptionLength)
            .MaximumLength(WorkshopValidationRules.MaxDescriptionLength);

        RuleFor(x => x.StartUtc)
            .GreaterThan(DateTime.UtcNow)
            .WithMessage("Workshop must be scheduled in the future.");

        RuleFor(x => x.EndUtc)
            .GreaterThan(x => x.StartUtc)
            .WithMessage("Workshop end time must be after its start time.");

        RuleFor(x => x.Type)
            .IsInEnum();

        RuleFor(x => x.Capacity)
            .InclusiveBetween(
                WorkshopValidationRules.MinCapacity,
                WorkshopValidationRules.MaxCapacity);

        RuleFor(x => x.Price)
            .GreaterThanOrEqualTo(0);

        RuleFor(x => x.RegistrationDeadlineUtc)
    .GreaterThan(DateTime.UtcNow)
    .WithMessage(
        "Registration deadline must be in the future.");

        RuleFor(x => x.RegistrationDeadlineUtc)
            .LessThanOrEqualTo(x => x.StartUtc)
            .WithMessage(
                "Registration deadline must be before or equal to workshop start time.");

        RuleFor(x => x.ImageUrl)
    .MaximumLength(
        WorkshopValidationRules
            .MaximumImageUrlLength)
    .WithMessage(
        "Image URL may contain at most 1000 characters.")
    .When(x =>
        !string.IsNullOrWhiteSpace(
            x.ImageUrl));


        When(x => x.Type == WorkshopType.Online, () =>
        {
            RuleFor(x => x.OnlineLink)
                .NotEmpty()
                .Must(url =>
                    Uri.TryCreate(
                        url,
                        UriKind.Absolute,
                        out var uri)
                    && (uri.Scheme == Uri.UriSchemeHttp
                        || uri.Scheme == Uri.UriSchemeHttps))
                .WithMessage(
                    "Online link must be a valid HTTP or HTTPS URL.");
        });

        When(x => x.Type == WorkshopType.InPerson, () =>
        {
            RuleFor(x => x.Location)
                .NotEmpty()
                .MaximumLength(300);
        });

        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .When(x => x.TherapistId.HasValue);
    }
}

public sealed class UpdateWorkshopStatusDtoValidator
    : AbstractValidator<UpdateWorkshopStatusDto>
{
    public UpdateWorkshopStatusDtoValidator()
    {
        RuleFor(x => x.Status)
            .IsInEnum();

        When(x => x.Status == WorkshopStatus.Cancelled, () =>
        {
            RuleFor(x => x.Reason)
                .NotEmpty()
                .MaximumLength(500);
        });

        When(x => !string.IsNullOrWhiteSpace(x.Reason), () =>
        {
            RuleFor(x => x.Reason)
                .MaximumLength(500);
        });
    }
}

public sealed class WorkshopQueryDtoValidator
    : AbstractValidator<WorkshopQueryDto>
{
    public WorkshopQueryDtoValidator()
    {
        RuleFor(x => x.PageNumber)
            .GreaterThan(0);

        RuleFor(x => x.PageSize)
            .InclusiveBetween(1, 50);

        RuleFor(x => x.Type)
            .IsInEnum()
            .When(x => x.Type.HasValue);

        RuleFor(x => x.Status)
            .IsInEnum()
            .When(x => x.Status.HasValue);

        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .When(x => x.TherapistId.HasValue);

        RuleFor(x => x.ToUtc)
            .GreaterThanOrEqualTo(x => x.FromUtc)
            .When(x =>
                x.FromUtc.HasValue &&
                x.ToUtc.HasValue);

        RuleFor(x => x.Search)
            .MaximumLength(150);
    }
}