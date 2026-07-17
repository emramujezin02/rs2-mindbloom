namespace MindBloom.Application.Features.Workshops.DTOs;

public class WorkshopRegistrationResponseDto
{
    public int Id { get; set; }

    public int WorkshopId { get; set; }

    public int ClientId { get; set; }

    public int ClientUserId { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public string Status { get; set; }
        = string.Empty;

    public DateTime RegisteredAtUtc { get; set; }

    public DateTime? CancelledAtUtc { get; set; }
}