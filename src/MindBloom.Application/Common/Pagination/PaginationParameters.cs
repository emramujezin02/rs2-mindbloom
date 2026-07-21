namespace MindBloom.Application.Common.Pagination;

public sealed record PaginationParameters(
    int PageNumber,
    int PageSize)
{
    public int Skip =>
        (PageNumber - 1) * PageSize;
}