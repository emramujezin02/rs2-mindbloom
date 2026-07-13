namespace MindBloom.Application.Features.Articles.DTOs;

public class ArticleQueryDto
{
    public string? Search { get; set; }

    public int? TherapistId { get; set; }

    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;
}