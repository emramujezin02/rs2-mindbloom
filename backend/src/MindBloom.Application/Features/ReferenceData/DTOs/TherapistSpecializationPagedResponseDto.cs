namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class TherapistSpecializationPagedResponseDto
{
    public IReadOnlyList<TherapistSpecializationResponseDto> Items { get; set; } =
        Array.Empty<TherapistSpecializationResponseDto>();

    public int PageNumber { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }

    public int TotalPages { get; set; }
}