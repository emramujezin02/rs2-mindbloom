using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class WorkshopRegistration : BaseEntity
{
    public int WorkshopId { get; set; }

    public Workshop Workshop { get; set; } =
        null!;

    public int ClientId { get; set; }

    public Client Client { get; set; } =
        null!;

    public WorkshopRegistrationStatus Status { get; set; } =
        WorkshopRegistrationStatus.Registered;

    public DateTime RegisteredAtUtc { get; set; }

    public DateTime? CancelledAtUtc { get; set; }
}