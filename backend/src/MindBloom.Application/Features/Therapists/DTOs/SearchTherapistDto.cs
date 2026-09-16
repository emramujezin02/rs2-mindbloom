namespace MindBloom.Application.Features.Therapists.DTOs;

public class SearchTherapistsDto
{
    public string? SearchText { get; set; }

    public string? Specialization { get; set; }

    public int? TherapyApproachId { get; set; }

    public string? Gender { get; set; }

    public string? Language { get; set; }

    public string? Location { get; set; }

    public string? SessionMode { get; set; }

    public decimal? MinPrice { get; set; }

    public decimal? MaxPrice { get; set; }

    public double? MinRating { get; set; }

    public DayOfWeek? AvailableDay { get; set; }

    public string? SortBy { get; set; }

    public string? SortDirection { get; set; }

    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;
}
