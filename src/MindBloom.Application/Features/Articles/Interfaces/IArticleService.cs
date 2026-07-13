using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Articles.DTOs;

namespace MindBloom.Application.Features.Articles.Interfaces;

public interface IArticleService
{
    Task<PagedResponse<ArticleResponseDto>>
        GetPublicAsync(
            ArticleQueryDto query);

    Task<ArticleResponseDto> GetByIdAsync(
        int articleId);

    Task<ArticleResponseDto> CreateAsync(
        int authorUserId,
        bool isAdmin,
        CreateArticleDto request);

    Task<ArticleResponseDto> UpdateAsync(
        int authorUserId,
        bool isAdmin,
        int articleId,
        UpdateArticleDto request);

    Task DeleteAsync(
        int authorUserId,
        bool isAdmin,
        int articleId);
}