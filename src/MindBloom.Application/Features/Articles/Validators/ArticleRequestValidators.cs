using FluentValidation;
using MindBloom.Application.Features.Articles.DTOs;

namespace MindBloom.Application.Features.Articles.Validators;

public static class ArticleValidationRules
{
    public const int MinimumTitleLength = 3;
    public const int MaximumTitleLength = 200;

    public const int MinimumDescriptionLength = 10;
    public const int MaximumDescriptionLength = 500;

    public const int MinimumContentLength = 20;
    public const int MaximumContentLength = 20000;

    public const int MaximumImageUrlLength = 1000;
    public const int MaximumSearchLength = 200;

    public const int MaximumPageSize = 50;

    public static bool IsValidImageUrl(
        string? imageUrl)
    {
        if (string.IsNullOrWhiteSpace(
                imageUrl))
        {
            return true;
        }

        var normalizedImageUrl =
            imageUrl.Trim();

        if (normalizedImageUrl.StartsWith(
                "/",
                StringComparison.Ordinal))
        {
            return true;
        }

        return Uri.TryCreate(
                   normalizedImageUrl,
                   UriKind.Absolute,
                   out var uri)
               &&
               (
                   uri.Scheme ==
                   Uri.UriSchemeHttp
                   ||
                   uri.Scheme ==
                   Uri.UriSchemeHttps
               );
    }
}

public sealed class CreateArticleDtoValidator
    : AbstractValidator<CreateArticleDto>
{
    public CreateArticleDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .WithMessage(
                "Article title is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Article title is required.")
            .MinimumLength(
                ArticleValidationRules
                    .MinimumTitleLength)
            .WithMessage(
                "Article title must contain at least 3 characters.")
            .MaximumLength(
                ArticleValidationRules
                    .MaximumTitleLength)
            .WithMessage(
                "Article title may contain at most 200 characters.");

        RuleFor(x => x.Description)
            .NotEmpty()
            .WithMessage(
                "Article description is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Article description is required.")
            .MinimumLength(
                ArticleValidationRules
                    .MinimumDescriptionLength)
            .WithMessage(
                "Article description must contain at least 10 characters.")
            .MaximumLength(
                ArticleValidationRules
                    .MaximumDescriptionLength)
            .WithMessage(
                "Article description may contain at most 500 characters.");

        RuleFor(x => x.Content)
            .NotEmpty()
            .WithMessage(
                "Article content is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Article content is required.")
            .MinimumLength(
                ArticleValidationRules
                    .MinimumContentLength)
            .WithMessage(
                "Article content must contain at least 20 characters.")
            .MaximumLength(
                ArticleValidationRules
                    .MaximumContentLength)
            .WithMessage(
                "Article content may contain at most 20000 characters.");

        RuleFor(x => x.ImageUrl)
            .MaximumLength(
                ArticleValidationRules
                    .MaximumImageUrlLength)
            .WithMessage(
                "Image URL may contain at most 1000 characters.")
            .Must(
                ArticleValidationRules
                    .IsValidImageUrl)
            .WithMessage(
                "Image URL must be an HTTP/HTTPS URL or a relative application path.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.ImageUrl));
    }
}

public sealed class UpdateArticleDtoValidator
    : AbstractValidator<UpdateArticleDto>
{
    public UpdateArticleDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .WithMessage(
                "Article title is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Article title is required.")
            .MinimumLength(
                ArticleValidationRules
                    .MinimumTitleLength)
            .WithMessage(
                "Article title must contain at least 3 characters.")
            .MaximumLength(
                ArticleValidationRules
                    .MaximumTitleLength)
            .WithMessage(
                "Article title may contain at most 200 characters.");

        RuleFor(x => x.Description)
            .NotEmpty()
            .WithMessage(
                "Article description is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Article description is required.")
            .MinimumLength(
                ArticleValidationRules
                    .MinimumDescriptionLength)
            .WithMessage(
                "Article description must contain at least 10 characters.")
            .MaximumLength(
                ArticleValidationRules
                    .MaximumDescriptionLength)
            .WithMessage(
                "Article description may contain at most 500 characters.");

        RuleFor(x => x.Content)
            .NotEmpty()
            .WithMessage(
                "Article content is required.")
            .Must(value =>
                !string.IsNullOrWhiteSpace(value))
            .WithMessage(
                "Article content is required.")
            .MinimumLength(
                ArticleValidationRules
                    .MinimumContentLength)
            .WithMessage(
                "Article content must contain at least 20 characters.")
            .MaximumLength(
                ArticleValidationRules
                    .MaximumContentLength)
            .WithMessage(
                "Article content may contain at most 20000 characters.");

        RuleFor(x => x.ImageUrl)
            .MaximumLength(
                ArticleValidationRules
                    .MaximumImageUrlLength)
            .WithMessage(
                "Image URL may contain at most 1000 characters.")
            .Must(
                ArticleValidationRules
                    .IsValidImageUrl)
            .WithMessage(
                "Image URL must be an HTTP/HTTPS URL or a relative application path.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.ImageUrl));
    }
}

public sealed class ArticleQueryDtoValidator
    : AbstractValidator<ArticleQueryDto>
{
    public ArticleQueryDtoValidator()
    {
        RuleFor(x => x.Search)
            .MaximumLength(
                ArticleValidationRules
                    .MaximumSearchLength)
            .WithMessage(
                "Search may contain at most 200 characters.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Search));

        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .WithMessage(
                "Therapist ID must be greater than zero.")
            .When(x =>
                x.TherapistId.HasValue);

        RuleFor(x => x.PageNumber)
            .GreaterThan(0)
            .WithMessage(
                "Page number must be greater than zero.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(
                1,
                ArticleValidationRules
                    .MaximumPageSize)
            .WithMessage(
                "Page size must be between 1 and 50.");
    }
}

public sealed class ArticleManagementQueryDtoValidator
    : AbstractValidator<ArticleManagementQueryDto>
{
    public ArticleManagementQueryDtoValidator()
    {
        RuleFor(x => x.Search)
            .MaximumLength(
                ArticleValidationRules
                    .MaximumSearchLength)
            .WithMessage(
                "Search may contain at most 200 characters.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Search));

        RuleFor(x => x.PageNumber)
            .GreaterThan(0)
            .WithMessage(
                "Page number must be greater than zero.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(
                1,
                ArticleValidationRules
                    .MaximumPageSize)
            .WithMessage(
                "Page size must be between 1 and 50.");
    }
}