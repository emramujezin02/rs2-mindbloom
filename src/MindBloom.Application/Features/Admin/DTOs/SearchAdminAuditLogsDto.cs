namespace MindBloom.Application.Features.Admin.DTOs;

public class SearchAdminAuditLogsDto
{
    private const int MaximumPageSize = 100;

    private int _pageNumber = 1;

    private int _pageSize = 10;

    public int? AdminUserId { get; set; }

    public string? Search { get; set; }

    public string? Action { get; set; }

    public string? EntityType { get; set; }

    public DateTime? FromUtc { get; set; }

    public DateTime? ToUtc { get; set; }

    public bool? IsSuccessful { get; set; }

    public int PageNumber
    {
        get => _pageNumber;

        set => _pageNumber =
            value < 1
                ? 1
                : value;
    }

    public int PageSize
    {
        get => _pageSize;

        set
        {
            if (value < 1)
            {
                _pageSize = 10;

                return;
            }

            _pageSize =
                value > MaximumPageSize
                    ? MaximumPageSize
                    : value;
        }
    }
}