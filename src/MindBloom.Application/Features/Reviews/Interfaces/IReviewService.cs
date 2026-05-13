using MindBloom.Application.Features.Reviews.DTOs;

namespace MindBloom.Application.Features.Reviews.Interfaces;

public interface IReviewService
{
    Task CreateAsync(int clientUserId,CreateReviewDto request);

    Task<List<ReviewResponseDto>>GetTherapistReviewsAsync(int therapistId);

    Task<TherapistRatingDto>GetTherapistRatingAsync(int therapistId);

    Task DeleteAsync(int clientUserId,int reviewId);

    Task UpdateAsync(int clientUserId,int reviewId,UpdateReviewDto request);
}