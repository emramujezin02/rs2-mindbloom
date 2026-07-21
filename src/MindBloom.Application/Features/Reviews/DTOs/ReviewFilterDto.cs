using MindBloom.Application.Common.Pagination;
using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Reviews.DTOs;

public class ReviewFilterDto
{
    public ReviewSortBy SortBy { get; set; } =
        ReviewSortBy.Newest;

    public int PageNumber { get; set; } =
        PaginationDefaults.DefaultPageNumber;

    public int PageSize { get; set; } =
        PaginationDefaults.DefaultPageSize;
}