using MindBloom.Application.Features.ReferenceData.DTOs;

namespace MindBloom.Application.Features.ReferenceData.Interfaces;

public interface IReferenceDataService
{
    Task<IReadOnlyList<TherapistSpecializationResponseDto>>
        GetActiveTherapistSpecializationsAsync(
            CancellationToken cancellationToken = default);

    Task<TherapistSpecializationPagedResponseDto>
        GetTherapistSpecializationsAsync(
            TherapistSpecializationQueryDto query,
            CancellationToken cancellationToken = default);

    Task<TherapistSpecializationResponseDto>
        GetTherapistSpecializationByIdAsync(
            int id,
            CancellationToken cancellationToken = default);

    Task<TherapistSpecializationResponseDto>
        CreateTherapistSpecializationAsync(
            CreateTherapistSpecializationDto request,
            CancellationToken cancellationToken = default);

    Task<TherapistSpecializationResponseDto>
        UpdateTherapistSpecializationAsync(
            int id,
            UpdateTherapistSpecializationDto request,
            CancellationToken cancellationToken = default);

    Task<TherapistSpecializationResponseDto>
        UpdateTherapistSpecializationStatusAsync(
            int id,
            UpdateTherapistSpecializationStatusDto request,
            CancellationToken cancellationToken = default);

    Task DeleteTherapistSpecializationAsync(
        int id,
        CancellationToken cancellationToken = default);
}