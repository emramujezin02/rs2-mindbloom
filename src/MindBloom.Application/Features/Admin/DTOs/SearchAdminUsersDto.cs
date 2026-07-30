namespace MindBloom.Application.Features.Admin.DTOs;

public class SearchAdminUsersDto
{
    private const int MaximumPageSize = 100;

    private int _pageNumber = 1;

    private int _pageSize = 10;

    public int PageNumber
    {
        get => _pageNumber;
        set => _pageNumber =
            value < 1 ? 1 : value;
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

    public string? Search { get; set; }

    public string? Role { get; set; }

    public bool? IsBlocked { get; set; }

    public DateTime? RegisteredFrom { get; set; }

    public DateTime? RegisteredTo { get; set; }
}