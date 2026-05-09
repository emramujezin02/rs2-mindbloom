using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Therapists.Interfaces;

public interface ITherapistService
{
    Task<TherapistResponseDto> CreateAsync(
        int userId,
        CreateTherapistDto request);

    Task<List<TherapistResponseDto>> GetAllAsync();

    Task AddAvailabilityAsync(
        int therapistId,
        CreateAvailabilityDto request);

    Task<List<AvailabilityResponseDto>>
        GetAvailabilitiesAsync(int therapistId);

    Task<List<TherapistResponseDto>>
    SearchAsync(SearchTherapistsDto request);
}