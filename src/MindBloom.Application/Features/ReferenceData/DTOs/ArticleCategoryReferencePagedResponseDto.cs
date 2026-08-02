namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class ArticleCategoryReferencePagedResponseDto
{
    public IReadOnlyList<ArticleCategoryReferenceResponseDto>
        Items
    { get; set; } =
            Array.Empty<ArticleCategoryReferenceResponseDto>();

    public int PageNumber { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }

    public int TotalPages { get; set; }
}