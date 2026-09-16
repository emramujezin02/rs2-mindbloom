using Microsoft.AspNetCore.Http;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Therapists.Interfaces;

public interface ITherapistService
{
    Task<TherapistResponseDto> CreateAsync(int userId,CreateTherapistDto request);

    Task<List<TherapistResponseDto>> GetAllAsync();

    Task AddAvailabilityAsync(
    int therapistUserId,
    CreateAvailabilityDto request);

    Task<List<AvailabilityResponseDto>> GetAvailabilitiesAsync(int therapistId);

    Task<PagedResponse<TherapistResponseDto>>SearchAsync(SearchTherapistsDto request);

    Task<List<TherapistResponseDto>>FilterAsync(TherapistFilterDto filter);

    Task UpdateProfileAsync(int therapistUserId,UpdateTherapistProfileDto request);

    Task<TherapistDetailsDto> GetByIdAsync(
    int therapistId,
    int? currentUserId);

    Task<TherapistDocumentDownloadDto>
    DownloadDocumentAsync(
        int authenticatedUserId,
        int documentId);

    Task DeleteAvailabilityAsync(int therapistUserId,int availabilityId);

    Task<TherapistDashboardDto>GetDashboardAsync(int therapistUserId);

    Task AddUnavailableDateAsync( int therapistUserId, CreateUnavailableDateDto request);

    Task<PagedResponse<UnavailableDateResponseDto>> GetUnavailableDatesAsync(
        int therapistId,
        int pageNumber,
        int pageSize,
        DateTime? fromUtc,
        DateTime? toUtc);
    Task UploadDocumentAsync(int therapistUserId,IFormFile file);

    Task<PagedResponse<TherapistDocumentResponseDto>>GetDocumentsAsync(
        int therapistId,
        int pageNumber,
        int pageSize);

    Task DeleteDocumentAsync(
        int therapistUserId,
        int documentId);
    Task DeleteUnavailableDateAsync(int therapistUserId, int unavailableDateId);

    Task<PagedResponse<TherapistClientListDto>>
        GetClientsAsync(
            int therapistUserId,
            string? search,
            int pageNumber,
            int pageSize);

    Task<TherapistClientDetailsDto>
        GetClientDetailsAsync(
            int therapistUserId,
            int clientId);

    Task<TherapistProfileDto> GetProfileAsync(
    int therapistUserId);

    Task<TherapistProfileImageDto> UploadProfileImageAsync(
        int therapistUserId,
        IFormFile file);

    Task DeleteProfileImageAsync(
        int therapistUserId);
}
