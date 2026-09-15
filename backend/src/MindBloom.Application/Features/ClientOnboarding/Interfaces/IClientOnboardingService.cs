using MindBloom.Application
    .Features.ClientOnboarding.DTOs;

namespace MindBloom.Application
    .Features.ClientOnboarding.Interfaces;

public interface IClientOnboardingService
{
    Task<ClientOnboardingDto> GetAsync(
        int userId,
        CancellationToken cancellationToken =
            default);

    Task<ClientOnboardingDto> SaveAsync(
        int userId,
        SaveClientOnboardingDto request,
        CancellationToken cancellationToken =
            default);
}
