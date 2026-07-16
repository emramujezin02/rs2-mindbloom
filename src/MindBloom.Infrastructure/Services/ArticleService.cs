using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Articles.DTOs;
using MindBloom.Application.Features.Articles.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class ArticleService : IArticleService
{
    private const int MaximumTitleLength = 200;
    private const int MaximumDescriptionLength = 500;
    private const int MaximumContentLength = 20000;
    private const int MaximumImageUrlLength = 1000;

    private readonly ApplicationDbContext _context;

    public ArticleService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<
        PagedResponse<ArticleResponseDto>>
        GetPublicAsync(
            ArticleQueryDto query)
    {
        var pageNumber =
            NormalizePageNumber(
                query.PageNumber);

        var pageSize =
            NormalizePageSize(
                query.PageSize);

        var articles =
            _context.Articles
                .AsNoTracking()
                .Include(x =>
                    x.AuthorUser)
                .Where(x =>
                    !x.IsDeleted &&
                    x.IsPublished);

        if (!string.IsNullOrWhiteSpace(
                query.Search))
        {
            var search =
                query.Search
                    .Trim()
                    .ToLower();

            articles =
                articles.Where(x =>
                    x.Title
                        .ToLower()
                        .Contains(search)
                    ||
                    x.Description
                        .ToLower()
                        .Contains(search)
                    ||
                    x.Content
                        .ToLower()
                        .Contains(search)
                    ||
                    (
                        x.AuthorUser.FirstName
                        + " "
                        + x.AuthorUser.LastName
                    )
                    .ToLower()
                    .Contains(search));
        }

        if (query.TherapistId.HasValue)
        {
            articles =
                articles.Where(x =>
                    x.TherapistId ==
                    query.TherapistId.Value);
        }

        return await CreatePagedResponseAsync(
            articles,
            pageNumber,
            pageSize);
    }

    public async Task<ArticleResponseDto>
        GetByIdAsync(
            int articleId)
    {
        var article =
            await _context.Articles
                .AsNoTracking()
                .Include(x =>
                    x.AuthorUser)
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    && !x.IsDeleted
                    && x.IsPublished);

        if (article == null)
        {
            throw new Exception(
                "Article not found.");
        }

        return MapToDto(article);
    }

    public async Task<
        PagedResponse<ArticleResponseDto>>
        GetManagementAsync(
            ArticleManagementQueryDto query)
    {
        var pageNumber =
            NormalizePageNumber(
                query.PageNumber);

        var pageSize =
            NormalizePageSize(
                query.PageSize);

        var articles =
            _context.Articles
                .AsNoTracking()
                .Include(x =>
                    x.AuthorUser)
                .Where(x =>
                    !x.IsDeleted);

        if (!string.IsNullOrWhiteSpace(
                query.Search))
        {
            var search =
                query.Search
                    .Trim()
                    .ToLower();

            articles =
                articles.Where(x =>
                    x.Title
                        .ToLower()
                        .Contains(search)
                    ||
                    x.Description
                        .ToLower()
                        .Contains(search)
                    ||
                    x.Content
                        .ToLower()
                        .Contains(search)
                    ||
                    (
                        x.AuthorUser.FirstName
                        + " "
                        + x.AuthorUser.LastName
                    )
                    .ToLower()
                    .Contains(search)
                    ||
                    (
                        x.AuthorUser.Email
                        ?? string.Empty
                    )
                    .ToLower()
                    .Contains(search));
        }

        if (query.IsPublished.HasValue)
        {
            articles =
                articles.Where(x =>
                    x.IsPublished ==
                    query.IsPublished.Value);
        }

        return await CreatePagedResponseAsync(
            articles,
            pageNumber,
            pageSize);
    }

    public async Task<ArticleResponseDto>
        GetManagementByIdAsync(
            int articleId)
    {
        var article =
            await _context.Articles
                .AsNoTracking()
                .Include(x =>
                    x.AuthorUser)
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    && !x.IsDeleted);

        if (article == null)
        {
            throw new Exception(
                "Article not found.");
        }

        return MapToDto(article);
    }

    public async Task<ArticleResponseDto>
        CreateAsync(
            int authorUserId,
            bool isAdmin,
            CreateArticleDto request)
    {
        Validate(
            request.Title,
            request.Description,
            request.Content,
            request.ImageUrl);

        var user =
            await _context.Users
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    authorUserId
                    && !x.IsBlocked);

        if (user == null)
        {
            throw new Exception(
                "Author not found.");
        }

        int? therapistId = null;

        if (!isAdmin)
        {
            var therapist =
                await _context.Therapists
                    .FirstOrDefaultAsync(x =>
                        x.UserId ==
                        authorUserId
                        && !x.IsDeleted);

            if (therapist == null)
            {
                throw new Exception(
                    "Therapist profile not found.");
            }

            therapistId =
                therapist.Id;
        }

        var now =
            DateTime.UtcNow;

        var article =
            new Article
            {
                Title =
                    request.Title.Trim(),

                Description =
                    request.Description.Trim(),

                Content =
                    request.Content.Trim(),

                ImageUrl =
                    NormalizeImageUrl(
                        request.ImageUrl),

                AuthorUserId =
                    authorUserId,

                TherapistId =
                    therapistId,

                IsPublished =
                    request.IsPublished,

                PublishedAtUtc =
                    now
            };

        _context.Articles.Add(
            article);

        await _context.SaveChangesAsync();

        article.AuthorUser =
            user;

        return MapToDto(
            article);
    }

    public async Task<ArticleResponseDto>
        UpdateAsync(
            int authorUserId,
            bool isAdmin,
            int articleId,
            UpdateArticleDto request)
    {
        Validate(
            request.Title,
            request.Description,
            request.Content,
            request.ImageUrl);

        var article =
            await _context.Articles
                .Include(x =>
                    x.AuthorUser)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    articleId
                    && !x.IsDeleted);

        if (article == null)
        {
            throw new Exception(
                "Article not found.");
        }

        EnsureCanManageArticle(
            article,
            authorUserId,
            isAdmin);

        article.Title =
            request.Title.Trim();

        article.Description =
            request.Description.Trim();

        article.Content =
            request.Content.Trim();

        article.ImageUrl =
            NormalizeImageUrl(
                request.ImageUrl);

        if (!article.IsPublished
            && request.IsPublished)
        {
            article.PublishedAtUtc =
                DateTime.UtcNow;
        }

        article.IsPublished =
            request.IsPublished;

        await _context.SaveChangesAsync();

        return MapToDto(
            article);
    }

    public async Task<ArticleResponseDto>
        UpdatePublicationAsync(
            int authorUserId,
            bool isAdmin,
            int articleId,
            UpdateArticlePublicationDto request)
    {
        var article =
            await _context.Articles
                .Include(x =>
                    x.AuthorUser)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    articleId
                    && !x.IsDeleted);

        if (article == null)
        {
            throw new Exception(
                "Article not found.");
        }

        EnsureCanManageArticle(
            article,
            authorUserId,
            isAdmin);

        if (article.IsPublished ==
            request.IsPublished)
        {
            return MapToDto(
                article);
        }

        article.IsPublished =
            request.IsPublished;

        if (request.IsPublished)
        {
            article.PublishedAtUtc =
                DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        return MapToDto(
            article);
    }

    public async Task DeleteAsync(
        int authorUserId,
        bool isAdmin,
        int articleId)
    {
        var article =
            await _context.Articles
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    articleId
                    && !x.IsDeleted);

        if (article == null)
        {
            throw new Exception(
                "Article not found.");
        }

        EnsureCanManageArticle(
            article,
            authorUserId,
            isAdmin);

        article.IsDeleted =
            true;

        article.IsPublished =
            false;

        await _context.SaveChangesAsync();
    }

    private static void EnsureCanManageArticle(
        Article article,
        int authenticatedUserId,
        bool isAdmin)
    {
        if (!isAdmin &&
            article.AuthorUserId !=
            authenticatedUserId)
        {
            throw new UnauthorizedAccessException(
                "You can manage only your own articles.");
        }
    }

    private static async Task<
        PagedResponse<ArticleResponseDto>>
        CreatePagedResponseAsync(
            IQueryable<Article> query,
            int pageNumber,
            int pageSize)
    {
        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.PublishedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    (pageNumber - 1)
                    * pageSize)
                .Take(pageSize)
                .Select(x =>
                    new ArticleResponseDto
                    {
                        Id =
                            x.Id,

                        Title =
                            x.Title,

                        Description =
                            x.Description,

                        Content =
                            x.Content,

                        ImageUrl =
                            x.ImageUrl
                            ?? string.Empty,

                        AuthorUserId =
                            x.AuthorUserId,

                        TherapistId =
                            x.TherapistId,

                        AuthorName =
                            x.AuthorUser.FirstName
                            + " "
                            + x.AuthorUser.LastName,

                        PublishedAtUtc =
                            x.PublishedAtUtc,

                        IsPublished =
                            x.IsPublished
                    })
                .ToListAsync();

        return new PagedResponse<ArticleResponseDto>
        {
            Items =
                items,

            PageNumber =
                pageNumber,

            PageSize =
                pageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalCount == 0
                    ? 0
                    : (int)Math.Ceiling(
                        totalCount
                        / (double)pageSize)
        };
    }

    private static int NormalizePageNumber(
        int pageNumber)
    {
        return pageNumber < 1
            ? 1
            : pageNumber;
    }

    private static int NormalizePageSize(
        int pageSize)
    {
        if (pageSize < 1)
        {
            return 10;
        }

        return Math.Min(
            pageSize,
            50);
    }

    private static void Validate(
        string title,
        string description,
        string content,
        string? imageUrl)
    {
        var normalizedTitle =
            title?.Trim()
            ?? string.Empty;

        var normalizedDescription =
            description?.Trim()
            ?? string.Empty;

        var normalizedContent =
            content?.Trim()
            ?? string.Empty;

        if (normalizedTitle.Length < 3)
        {
            throw new Exception(
                "Article title must contain at least 3 characters.");
        }

        if (normalizedTitle.Length >
            MaximumTitleLength)
        {
            throw new Exception(
                "Article title may contain at most 200 characters.");
        }

        if (normalizedDescription.Length < 10)
        {
            throw new Exception(
                "Article description must contain at least 10 characters.");
        }

        if (normalizedDescription.Length >
            MaximumDescriptionLength)
        {
            throw new Exception(
                "Article description may contain at most 500 characters.");
        }

        if (normalizedContent.Length < 20)
        {
            throw new Exception(
                "Article content must contain at least 20 characters.");
        }

        if (normalizedContent.Length >
            MaximumContentLength)
        {
            throw new Exception(
                "Article content may contain at most 20000 characters.");
        }

        if (!string.IsNullOrWhiteSpace(
                imageUrl))
        {
            var normalizedImageUrl =
                imageUrl.Trim();

            if (normalizedImageUrl.Length >
                MaximumImageUrlLength)
            {
                throw new Exception(
                    "Image URL may contain at most 1000 characters.");
            }

            var isRelative =
                normalizedImageUrl
                    .StartsWith('/');

            var isValidAbsolute =
                Uri.TryCreate(
                    normalizedImageUrl,
                    UriKind.Absolute,
                    out var uri)
                && (
                    uri.Scheme ==
                    Uri.UriSchemeHttp
                    ||
                    uri.Scheme ==
                    Uri.UriSchemeHttps
                );

            if (!isRelative &&
                !isValidAbsolute)
            {
                throw new Exception(
                    "Image URL must be an HTTP/HTTPS URL or a relative application path.");
            }
        }
    }

    private static string?
        NormalizeImageUrl(
            string? imageUrl)
    {
        return string.IsNullOrWhiteSpace(
                imageUrl)
            ? null
            : imageUrl.Trim();
    }

    private static ArticleResponseDto
        MapToDto(
            Article article)
    {
        return new ArticleResponseDto
        {
            Id =
                article.Id,

            Title =
                article.Title,

            Description =
                article.Description,

            Content =
                article.Content,

            ImageUrl =
                article.ImageUrl
                ?? string.Empty,

            AuthorUserId =
                article.AuthorUserId,

            TherapistId =
                article.TherapistId,

            AuthorName =
                article.AuthorUser.FirstName
                + " "
                + article.AuthorUser.LastName,

            PublishedAtUtc =
                article.PublishedAtUtc,

            IsPublished =
                article.IsPublished
        };
    }
}