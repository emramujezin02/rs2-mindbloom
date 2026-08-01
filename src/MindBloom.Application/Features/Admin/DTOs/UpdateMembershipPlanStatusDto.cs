namespace MindBloom.Application.Features.Admin.DTOs;

public class UpdateMembershipPlanStatusDto
{
    public bool IsActive { get; set; }

    public string? Reason { get; set; }
}