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

    Task<IReadOnlyList<TherapyApproachResponseDto>>
        GetActiveTherapyApproachesAsync(
            CancellationToken cancellationToken = default);

    Task<TherapyApproachPagedResponseDto>
        GetTherapyApproachesAsync(
            TherapyApproachQueryDto query,
            CancellationToken cancellationToken = default);

    Task<TherapyApproachResponseDto>
        GetTherapyApproachByIdAsync(
            int id,
            CancellationToken cancellationToken = default);

    Task<TherapyApproachResponseDto>
        CreateTherapyApproachAsync(
            CreateTherapyApproachDto request,
            CancellationToken cancellationToken = default);

    Task<TherapyApproachResponseDto>
        UpdateTherapyApproachAsync(
            int id,
            UpdateTherapyApproachDto request,
            CancellationToken cancellationToken = default);

    Task<TherapyApproachResponseDto>
        UpdateTherapyApproachStatusAsync(
            int id,
            UpdateTherapyApproachStatusDto request,
            CancellationToken cancellationToken = default);

    Task DeleteTherapyApproachAsync(
        int id,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ArticleCategoryReferenceResponseDto>>
    GetActiveArticleCategoriesAsync(
        CancellationToken cancellationToken = default);

    Task<ArticleCategoryReferencePagedResponseDto>
        GetArticleCategoriesAsync(
            ArticleCategoryReferenceQueryDto query,
            CancellationToken cancellationToken = default);

    Task<ArticleCategoryReferenceResponseDto>
        GetArticleCategoryByIdAsync(
            int id,
            CancellationToken cancellationToken = default);

    Task<ArticleCategoryReferenceResponseDto>
        CreateArticleCategoryAsync(
            CreateArticleCategoryReferenceDto request,
            CancellationToken cancellationToken = default);

    Task<ArticleCategoryReferenceResponseDto>
        UpdateArticleCategoryAsync(
            int id,
            UpdateArticleCategoryReferenceDto request,
            CancellationToken cancellationToken = default);

    Task<ArticleCategoryReferenceResponseDto>
        UpdateArticleCategoryStatusAsync(
            int id,
            UpdateArticleCategoryReferenceStatusDto request,
            CancellationToken cancellationToken = default);

    Task DeleteArticleCategoryAsync(
        int id,
        CancellationToken cancellationToken = default);
}