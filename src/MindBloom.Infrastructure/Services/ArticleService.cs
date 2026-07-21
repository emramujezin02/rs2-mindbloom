using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Articles.DTOs;
using MindBloom.Application.Features.Articles.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class ArticleService : IArticleService
{

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
            query.PageNumber;

        var pageSize =
            query.PageSize;

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
            throw new NotFoundException(
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
            query.PageNumber;

        var pageSize =
            query.PageSize;

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
            throw new NotFoundException(
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
       

        var user =
            await _context.Users
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    authorUserId
                    && !x.IsBlocked);

        if (user == null)
        {
            throw new NotFoundException(
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
                throw new NotFoundException(
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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