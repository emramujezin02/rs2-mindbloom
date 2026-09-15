using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Workshops.DTOs;

public class WorkshopQueryDto
{
    public string? Search { get; set; }

    public WorkshopType? Type { get; set; }

    public WorkshopStatus? Status { get; set; }

    public int? TherapistId { get; set; }

    public DateTime? FromUtc { get; set; }

    public DateTime? ToUtc { get; set; }

    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;
}