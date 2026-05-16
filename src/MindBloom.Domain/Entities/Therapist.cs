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

    public string? ProfileImagePath { get; set; }

    public ICollection<AppointmentNote> AppointmentNotes { get; set; } = new List<AppointmentNote>();

    public ICollection<TherapistAvailability> Availabilities { get; set; } = new List<TherapistAvailability>();

    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public ICollection<Review> Reviews { get; set; }= new List<Review>();

    public ICollection<TherapistUnavailableDate>UnavailableDates{ get; set; } = new List<TherapistUnavailableDate>();

    public ICollection<TherapistDocument>Documents { get; set; } = new List<TherapistDocument>();
}
