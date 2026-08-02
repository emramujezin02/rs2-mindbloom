namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class CreateTherapyApproachDto
{
    public string Name { get; set; } =
        string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;
}