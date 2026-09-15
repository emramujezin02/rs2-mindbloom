namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class TherapyApproachResponseDto
{
    public int Id { get; set; }

    public string Name { get; set; } =
        string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; }

    public int TherapistCount { get; set; }

    public int ClientCount { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }
}