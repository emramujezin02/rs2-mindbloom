namespace MindBloom.Domain.Entities;

public class Therapist : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public string Biography { get; set; } = null!;

    public string Specialization { get; set; } = null!;

    public decimal PricePerSession { get; set; }

    public bool IsVerified { get; set; }

    public ICollection<TherapistAvailability> Availabilities { get; set; }
        = new List<TherapistAvailability>();

    public ICollection<Appointment> Appointments { get; set; }
        = new List<Appointment>();
}