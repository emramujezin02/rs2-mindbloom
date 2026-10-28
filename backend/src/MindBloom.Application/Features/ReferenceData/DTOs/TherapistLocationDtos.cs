namespace MindBloom.Application.Features.ReferenceData.DTOs;

public sealed class TherapistLocationResponseDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public string DisplayName => string.Join(", ", new[] { Name, Region, Country }.Where(x => !string.IsNullOrEmpty(x)));
    public bool IsActive { get; set; }
    public int TherapistCount { get; set; }
}

public sealed class TherapistLocationQueryDto
{
    public string? Search { get; set; }
    public bool? IsActive { get; set; }
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}

public sealed class SaveTherapistLocationDto
{
    public string Name { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}
