namespace MindBloom.Application.Common.Models;

public sealed class PagedResponse<T>
{
    public List<T> Items { get; init; } = [];

    public int PageNumber { get; init; }

    public int PageSize { get; init; }

    public int TotalCount { get; init; }

    public int TotalPages { get; init; }

    public bool HasPreviousPage =>
        PageNumber > 1;

    public bool HasNextPage =>
        PageNumber < TotalPages;

    public static PagedResponse<T> Create(
        List<T> items,
        int pageNumber,
        int pageSize,
        int totalCount)
    {
        return new PagedResponse<T>
        {
            Items =
                items,

            PageNumber =
                pageNumber,

            PageSize =
                pageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalCount == 0
                    ? 0
                    : (int)Math.Ceiling(
                        totalCount /
                        (double)pageSize)
        };
    }
}