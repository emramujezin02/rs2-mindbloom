using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Admin.DTOs;

public class SearchAdminPaymentsDto
{
    private const int MaximumPageSize = 100;

    private int _pageNumber = 1;

    private int _pageSize = 10;

    public string? Search { get; set; }

    public PaymentStatus? Status { get; set; }

    public DateTime? DateFromUtc { get; set; }

    public DateTime? DateToUtc { get; set; }

    public decimal? MinimumAmount { get; set; }

    public decimal? MaximumAmount { get; set; }

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