using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.Articles.DTOs;
using MindBloom.Application.Features.Articles.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using System;

namespace MindBloom.Infrastructure.Services;

public class ArticleService : IArticleService
{
    private readonly ApplicationDbContext _context;

    public ArticleService(
        ApplicationDbContext context,
            IWebHostEnvironment environment)
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
    request.IsPublished
        ? DateTime.UtcNow
        : null,

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

    public async Task<ArticleImageUploadDto>
    UploadImageAsync(
        IFormFile file)
    {
        if (file == null ||
            file.Length == 0)
        {
            throw new Exception(
                "Article image is required.");
        }

        const long maximumFileSize =
            5 * 1024 * 1024;

        if (file.Length > maximumFileSize)
        {
            throw new Exception(
                "Article image may not exceed 5 MB.");
        }

        var extension =
            Path.GetExtension(file.FileName)
                .ToLowerInvariant();

        var allowedExtensions =
            new HashSet<string>
            {
            ".jpg",
            ".jpeg",
            ".png",
            ".webp"
            };

        if (!allowedExtensions.Contains(
                extension))
        {
            throw new Exception(
                "Only JPG, JPEG, PNG and WEBP images are allowed.");
        }

        var allowedContentTypes =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "image/jpeg",
            "image/png",
            "image/webp"
            };

        if (!allowedContentTypes.Contains(
                file.ContentType))
        {
            throw new Exception(
                "Invalid image content type.");
        }

        await using var validationStream =
            file.OpenReadStream();

        var header = new byte[12];

        var bytesRead =
            await validationStream.ReadAsync(
                header.AsMemory(
                    0,
                    header.Length));

        if (bytesRead < 4)
        {
            throw new Exception(
                "Invalid image file.");
        }

        var isJpeg =
            header[0] == 0xFF &&
            header[1] == 0xD8 &&
            header[2] == 0xFF;

        var isPng =
            bytesRead >= 8 &&
            header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4E &&
            header[3] == 0x47 &&
            header[4] == 0x0D &&
            header[5] == 0x0A &&
            header[6] == 0x1A &&
            header[7] == 0x0A;

        var isWebp =
            bytesRead >= 12 &&
            header[0] == 0x52 &&
            header[1] == 0x49 &&
            header[2] == 0x46 &&
            header[3] == 0x46 &&
            header[8] == 0x57 &&
            header[9] == 0x45 &&
            header[10] == 0x42 &&
            header[11] == 0x50;

        var signatureMatchesExtension =
            extension switch
            {
                ".jpg" or ".jpeg" =>
                    isJpeg,

                ".png" =>
                    isPng,

                ".webp" =>
                    isWebp,

                _ => false
            };

        if (!signatureMatchesExtension)
        {
            throw new Exception(
                "The uploaded file is not a valid image.");
        }

        var webRootPath =
            environment.WebRootPath;

        if (string.IsNullOrWhiteSpace(
                webRootPath))
        {
            webRootPath =
                Path.Combine(
                    environment.ContentRootPath,
                    "wwwroot");
        }

        var uploadDirectory =
            Path.Combine(
                webRootPath,
                "uploads",
                "articles");

        Directory.CreateDirectory(
            uploadDirectory);

        var safeFileName =
            $"{Guid.NewGuid():N}{extension}";

        var physicalPath =
            Path.Combine(
                uploadDirectory,
                safeFileName);

        await using (
            var outputStream =
                new FileStream(
                    physicalPath,
                    FileMode.CreateNew))
        {
            await file.CopyToAsync(
                outputStream);
        }

        return new ArticleImageUploadDto
        {
            ImageUrl =
                $"/uploads/articles/{safeFileName}"
        };
    }
}