namespace MindBloom.Application.Features.Admin.DTOs;

public class UpdateMembershipPlanDto
{
    public string Name { get; set; }
        = string.Empty;

    public string Description { get; set; }
        = string.Empty;

    public decimal Price { get; set; }

    public int DurationMonths { get; set; }

    public int IncludedSessions { get; set; }

    public decimal DiscountPercentage { get; set; }

    public List<string> Benefits { get; set; }
        = [];
}