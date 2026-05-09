namespace MindBloom.Application.Features.Therapists.DTOs;

public class SearchTherapistsDto
{
    public string? Name { get; set; }

    public string? Specialization { get; set; }

    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;

    public string? SortBy { get; set; }
}