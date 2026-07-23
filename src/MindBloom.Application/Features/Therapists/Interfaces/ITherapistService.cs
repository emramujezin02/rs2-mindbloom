using Microsoft.AspNetCore.Http;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Therapists.Interfaces;

public interface ITherapistService
{
    Task<TherapistResponseDto> CreateAsync(int userId,CreateTherapistDto request);

    Task<List<TherapistResponseDto>> GetAllAsync();

    Task AddAvailabilityAsync(int therapistId,CreateAvailabilityDto request);
    
    Task<List<AvailabilityResponseDto>> GetAvailabilitiesAsync(int therapistId);

    Task<PagedResponse<TherapistResponseDto>>SearchAsync(SearchTherapistsDto request);

    Task<List<TherapistResponseDto>>FilterAsync(TherapistFilterDto filter);

    Task UpdateProfileAsync(int therapistUserId,UpdateTherapistProfileDto request);

    Task<TherapistDetailsDto> GetByIdAsync(
    int therapistId,
    int? currentUserId);

    Task DeleteAvailabilityAsync(int therapistUserId,int availabilityId);

    Task<TherapistDashboardDto>GetDashboardAsync(int therapistUserId);

    Task AddUnavailableDateAsync( int therapistUserId, CreateUnavailableDateDto request);

    Task<List<UnavailableDateResponseDto>> GetUnavailableDatesAsync(int therapistId);
    Task UploadDocumentAsync(int therapistUserId,IFormFile file);

    Task<List<TherapistDocumentResponseDto>>GetDocumentsAsync(int therapistId);

    Task DeleteDocumentAsync(
        int therapistUserId,
        int documentId);
    Task DeleteUnavailableDateAsync(int therapistUserId, int unavailableDateId);

    Task<List<TherapistClientListDto>>
        GetClientsAsync(
            int therapistUserId,
            string? search);

    Task<TherapistClientDetailsDto>
        GetClientDetailsAsync(
            int therapistUserId,
            int clientId);

    Task<TherapistProfileDto> GetProfileAsync(
    int therapistUserId);

    Task<TherapistProfileImageDto> UploadProfileImageAsync(
        int therapistUserId,
        IFormFile file);
}