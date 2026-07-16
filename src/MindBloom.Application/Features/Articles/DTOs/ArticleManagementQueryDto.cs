namespace MindBloom.Application.Features.Articles.DTOs;

public class ArticleManagementQueryDto
{
    public string? Search { get; set; }

    public bool? IsPublished { get; set; }

    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;
}