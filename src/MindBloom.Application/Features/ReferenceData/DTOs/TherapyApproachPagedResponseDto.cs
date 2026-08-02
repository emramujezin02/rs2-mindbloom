namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class TherapyApproachPagedResponseDto
{
    public IReadOnlyList<TherapyApproachResponseDto>
        Items
    { get; set; } =
            Array.Empty<TherapyApproachResponseDto>();

    public int PageNumber { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }

    public int TotalPages { get; set; }
}