using MindBloom.Application.Recommendations.DTOs;

namespace MindBloom.Application.Recommendations.Services;

public interface IRecommendationService
{
    Task<IReadOnlyList<TherapistRecommendationDto>>
        GetRecommendationsAsync(
            int userId,
            TherapistRecommendationRequestDto request,
            CancellationToken cancellationToken = default);
}