using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Reviews.DTOs;

namespace MindBloom.Application.Features.Reviews.Interfaces;

public interface IReviewService
{
    Task CreateAsync(
        int clientUserId,
        CreateReviewDto request);

    Task<List<PublicReviewDto>>
        GetPublicReviewsAsync(
            int limit);

    Task<PagedResponse<ReviewResponseDto>>
        GetTherapistReviewsAsync(
            int therapistId,
            ReviewFilterDto filter);

    Task<TherapistRatingDto>
        GetTherapistRatingAsync(
            int therapistId);

    Task DeleteAsync(
        int clientUserId,
        int reviewId);

    Task UpdateAsync(
        int clientUserId,
        int reviewId,
        UpdateReviewDto request);

    Task<PagedResponse<ClientReviewDto>>
        GetMyReviewsAsync(
            int clientUserId,
            int pageNumber,
            int pageSize);

    Task ReplyToReviewAsync(
        int therapistUserId,
        int reviewId,
        ReplyToReviewDto request);
}