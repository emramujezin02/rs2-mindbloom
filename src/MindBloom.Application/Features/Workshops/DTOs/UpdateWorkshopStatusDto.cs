using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Workshops.DTOs;

public class UpdateWorkshopStatusDto
{
    public WorkshopStatus Status { get; set; }

    public string? Reason { get; set; }
}