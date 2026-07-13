namespace MindBloom.Application.Features.Workshops.DTOs;

public class WorkshopResponseDto
{
    public int Id { get; set; }

    public string Title { get; set; } =
        string.Empty;

    public string Description { get; set; } =
        string.Empty;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Type { get; set; } =
        string.Empty;

    public string? OnlineLink { get; set; }

    public string? Location { get; set; }

    public int Capacity { get; set; }

    public int RegisteredCount { get; set; }

    public int AvailableSeats { get; set; }

    public decimal Price { get; set; }

    public string Status { get; set; } =
        string.Empty;

    public int OrganizerUserId { get; set; }

    public string OrganizerName { get; set; } =
        string.Empty;

    public int? TherapistId { get; set; }

    public bool IsRegistered { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public string? StatusChangeReason { get; set; }
}