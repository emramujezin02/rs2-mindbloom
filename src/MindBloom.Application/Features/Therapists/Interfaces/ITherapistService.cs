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
}