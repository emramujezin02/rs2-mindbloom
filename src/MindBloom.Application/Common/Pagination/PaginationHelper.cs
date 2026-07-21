namespace MindBloom.Application.Common.Pagination;

public static class PaginationHelper
{
    public static PaginationParameters Normalize(
        int pageNumber,
        int pageSize)
    {
        var normalizedPageNumber =
            pageNumber <
            PaginationDefaults.DefaultPageNumber
                ? PaginationDefaults.DefaultPageNumber
                : pageNumber;

        var normalizedPageSize =
            pageSize < 1
                ? PaginationDefaults.DefaultPageSize
                : Math.Min(
                    pageSize,
                    PaginationDefaults.MaximumPageSize);

        return new PaginationParameters(
            normalizedPageNumber,
            normalizedPageSize);
    }
}