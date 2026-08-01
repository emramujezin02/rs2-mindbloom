using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Workshops.DTOs;

public class UpdateWorkshopDto
{
    public string Title { get; set; } =
        string.Empty;

    public string Description { get; set; } =
        string.Empty;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public WorkshopType Type { get; set; }

    public string? OnlineLink { get; set; }

    public string? Location { get; set; }

    public int Capacity { get; set; }

    public decimal Price { get; set; }

    public int? TherapistId { get; set; }
    public string? ImageUrl { get; set; }

    public DateTime RegistrationDeadlineUtc { get; set; }
}