using Microsoft.AspNetCore.Http;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Articles.DTOs;

namespace MindBloom.Application.Features.Articles.Interfaces;

public interface IArticleService
{
    Task<PagedResponse<ArticleResponseDto>>
        GetPublicAsync(
            ArticleQueryDto query);

    Task<ArticleResponseDto>
        GetByIdAsync(
            int articleId);

    Task<List<ArticleCategoryResponseDto>>
        GetCategoriesAsync();

    Task<PagedResponse<ArticleResponseDto>>
        GetManagementAsync(
            ArticleManagementQueryDto query);

    Task<ArticleResponseDto>
        GetManagementByIdAsync(
            int articleId);

    Task<ArticleResponseDto>
        CreateAsync(
            int authorUserId,
            bool isAdmin,
            CreateArticleDto request);

    Task<ArticleResponseDto>
        UpdateAsync(
            int authorUserId,
            bool isAdmin,
            int articleId,
            UpdateArticleDto request);

    Task<ArticleResponseDto>
        UpdatePublicationAsync(
            int authorUserId,
            bool isAdmin,
            int articleId,
            UpdateArticlePublicationDto request);

    Task DeleteAsync(
        int authorUserId,
        bool isAdmin,
        int articleId);

    Task<ArticleImageUploadDto>
    UploadImageAsync(
        IFormFile file);
}