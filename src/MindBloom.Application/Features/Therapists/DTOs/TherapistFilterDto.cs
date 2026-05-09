namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistFilterDto
{
    public string? SearchTerm { get; set; }

    public string? Specialization { get; set; }

    public decimal? MinPrice { get; set; }

    public decimal? MaxPrice { get; set; }

    public bool SortByRating { get; set; }
}