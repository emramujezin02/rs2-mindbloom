using MindBloom.Application.Features.Privacy.DTOs;

namespace MindBloom.Application.Features.Privacy.Interfaces;

public interface IPrivacyConsentService
{
    Task<List<UserConsentDto>>
        GetMyConsentsAsync(
            int userId);

    CurrentConsentVersionsDto
        GetCurrentVersions();
}