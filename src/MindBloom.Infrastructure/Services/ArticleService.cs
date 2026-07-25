using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;
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

    public async Task<PagedResponse<ArticleResponseDto>>
        GetPublicAsync(
            ArticleQueryDto query)
    {
        var pagination =
            PaginationHelper.Normalize(
                query.PageNumber,
                query.PageSize);

        var articles =
            _context.Articles
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.IsPublished)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search =
                query.Search.Trim().ToLower();

            articles =
                articles.Where(x =>
                    x.Title.ToLower().Contains(search)
                    ||
                    x.Description.ToLower().Contains(search)
                    ||
                    x.Content.ToLower().Contains(search)
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

        if (query.ArticleCategoryId.HasValue)
        {
            articles =
                articles.Where(x =>
                    x.ArticleCategoryId ==
                    query.ArticleCategoryId.Value);
        }

        return await CreatePagedResponseAsync(
            articles,
            pagination);
    }

    public async Task<ArticleResponseDto>
        GetByIdAsync(
            int articleId)
    {
        var article =
            await _context.Articles
                .AsNoTracking()
                .Include(x => x.AuthorUser)
                .Include(x => x.ArticleCategory)
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    &&
                    !x.IsDeleted
                    &&
                    x.IsPublished);

        if (article == null)
        {
            throw new NotFoundException(
                "Article not found.");
        }

        return MapToDto(article);
    }

    public async Task<List<ArticleCategoryResponseDto>>
        GetCategoriesAsync()
    {
        return await _context.ArticleCategories
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                x.IsActive)
            .OrderBy(x => x.Name)
            .Select(x =>
                new ArticleCategoryResponseDto
                {
                    Id = x.Id,
                    Name = x.Name
                })
            .ToListAsync();
    }

    public async Task<PagedResponse<ArticleResponseDto>>
        GetManagementAsync(
            ArticleManagementQueryDto query)
    {
        var pagination =
            PaginationHelper.Normalize(
                query.PageNumber,
                query.PageSize);

        var articles =
            _context.Articles
                .AsNoTracking()
                .Where(x => !x.IsDeleted)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search =
                query.Search.Trim().ToLower();

            articles =
                articles.Where(x =>
                    x.Title.ToLower().Contains(search)
                    ||
                    x.Description.ToLower().Contains(search)
                    ||
                    x.Content.ToLower().Contains(search)
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
            pagination);
    }

    public async Task<ArticleResponseDto>
        GetManagementByIdAsync(
            int articleId)
    {
        var article =
            await _context.Articles
                .AsNoTracking()
                .Include(x => x.AuthorUser)
                .Include(x => x.ArticleCategory)
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    &&
                    !x.IsDeleted);

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
                    x.Id == authorUserId
                    &&
                    !x.IsBlocked);

        if (user == null)
        {
            throw new NotFoundException(
                "Author not found.");
        }

        var category =
            await GetActiveCategoryAsync(
                request.ArticleCategoryId);

        int? therapistId = null;

        if (!isAdmin)
        {
            var therapist =
                await _context.Therapists
                    .FirstOrDefaultAsync(x =>
                        x.UserId == authorUserId
                        &&
                        !x.IsDeleted);

            if (therapist == null)
            {
                throw new NotFoundException(
                    "Therapist profile not found.");
            }

            therapistId = therapist.Id;
        }

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

                ArticleCategoryId =
                    category.Id,

                PublishedAtUtc =
                    DateTime.UtcNow,

                IsPublished =
                    request.IsPublished
            };

        _context.Articles.Add(article);

        await _context.SaveChangesAsync();

        article.AuthorUser = user;
        article.ArticleCategory = category;

        return MapToDto(article);
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
                .Include(x => x.AuthorUser)
                .Include(x => x.ArticleCategory)
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    &&
                    !x.IsDeleted);

        if (article == null)
        {
            throw new NotFoundException(
                "Article not found.");
        }

        EnsureCanManageArticle(
            article,
            authorUserId,
            isAdmin);

        var category =
            await GetActiveCategoryAsync(
                request.ArticleCategoryId);

        article.Title =
            request.Title.Trim();

        article.Description =
            request.Description.Trim();

        article.Content =
            request.Content.Trim();

        article.ImageUrl =
            NormalizeImageUrl(
                request.ImageUrl);

        article.ArticleCategoryId =
            category.Id;

        article.ArticleCategory =
            category;

        if (!article.IsPublished &&
            request.IsPublished)
        {
            article.PublishedAtUtc =
                DateTime.UtcNow;
        }

        article.IsPublished =
            request.IsPublished;

        await _context.SaveChangesAsync();

        return MapToDto(article);
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
                .Include(x => x.AuthorUser)
                .Include(x => x.ArticleCategory)
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    &&
                    !x.IsDeleted);

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
            return MapToDto(article);
        }

        article.IsPublished =
            request.IsPublished;

        if (request.IsPublished)
        {
            article.PublishedAtUtc =
                DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        return MapToDto(article);
    }

    public async Task DeleteAsync(
        int authorUserId,
        bool isAdmin,
        int articleId)
    {
        var article =
            await _context.Articles
                .FirstOrDefaultAsync(x =>
                    x.Id == articleId
                    &&
                    !x.IsDeleted);

        if (article == null)
        {
            throw new NotFoundException(
                "Article not found.");
        }

        EnsureCanManageArticle(
            article,
            authorUserId,
            isAdmin);

        article.IsDeleted = true;
        article.IsPublished = false;

        await _context.SaveChangesAsync();
    }

    private async Task<ArticleCategory>
        GetActiveCategoryAsync(
            int articleCategoryId)
    {
        var category =
            await _context.ArticleCategories
                .FirstOrDefaultAsync(x =>
                    x.Id == articleCategoryId
                    &&
                    !x.IsDeleted
                    &&
                    x.IsActive);

        if (category == null)
        {
            throw new NotFoundException(
                "Article category not found.");
        }

        return category;
    }

    private static void EnsureCanManageArticle(
        Article article,
        int authenticatedUserId,
        bool isAdmin)
    {
        if (!isAdmin &&
            article.AuthorUserId != authenticatedUserId)
        {
            throw new UnauthorizedAccessException(
                "You can manage only your own articles.");
        }
    }

    private static async Task<
        PagedResponse<ArticleResponseDto>>
        CreatePagedResponseAsync(
            IQueryable<Article> query,
            PaginationParameters pagination)
    {
        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.PublishedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(pagination.Skip)
                .Take(pagination.PageSize)
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
                            x.IsPublished,

                        ArticleCategoryId =
                            x.ArticleCategoryId,

                        ArticleCategoryName =
                            x.ArticleCategory != null
                                ? x.ArticleCategory.Name
                                : string.Empty
                    })
                .ToListAsync();

        return PagedResponse<ArticleResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    private static string?
        NormalizeImageUrl(
            string? imageUrl)
    {
        return string.IsNullOrWhiteSpace(imageUrl)
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
                article.IsPublished,

            ArticleCategoryId =
                article.ArticleCategoryId,

            ArticleCategoryName =
                article.ArticleCategory?.Name
                ?? string.Empty
        };
    }
}