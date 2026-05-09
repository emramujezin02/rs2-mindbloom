namespace MindBloom.Domain.Entities;

public class Therapist : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public string Biography { get; set; } = null!;

    public string Specialization { get; set; } = null!;

    public decimal PricePerSession { get; set; }

    public bool IsVerified { get; set; }

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }

    public ICollection<TherapistAvailability> Availabilities { get; set; } = new List<TherapistAvailability>();

    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public ICollection<Review> Reviews { get; set; }= new List<Review>();
}
