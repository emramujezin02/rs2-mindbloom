namespace MindBloom.Application.Features.Admin.DTOs;

public class SearchAdminReviewsDto
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

    public int? Rating { get; set; }

    public bool? HasTherapistReply { get; set; }

    public bool? IsDeleted { get; set; }
    public bool? IsApproved { get; set; }
}