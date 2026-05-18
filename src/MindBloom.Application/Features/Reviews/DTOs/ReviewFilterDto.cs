using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Reviews.DTOs;

public class ReviewFilterDto
{
    public ReviewSortBy SortBy { get; set; }
        = ReviewSortBy.Newest;
}