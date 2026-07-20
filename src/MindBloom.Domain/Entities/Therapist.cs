using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Therapist : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public string Biography { get; set; } = null!;

    public string Specialization { get; set; } = null!;

    public int? SpecializationId { get; set; }

    public TherapistSpecialization? SpecializationReference { get; set; }

    public decimal PricePerSession { get; set; }

    public TherapistVerificationStatus VerificationStatus { get; set; }

    public string? VerificationNotes { get; set; }

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }

    public string? ProfileImagePath { get; set; }

    public string? Location { get; set; }

    public string Country { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string Address { get; set; } = string.Empty;

    public bool OffersOnline { get; set; }

    public bool OffersInPerson { get; set; }

    public string? Languages { get; set; }

    public ICollection<AppointmentNote> AppointmentNotes { get; set; } =
        new List<AppointmentNote>();

    public ICollection<TherapistAvailability> Availabilities { get; set; } =
        new List<TherapistAvailability>();

    public ICollection<Appointment> Appointments { get; set; } =
        new List<Appointment>();

    public ICollection<Review> Reviews { get; set; } =
        new List<Review>();

    public ICollection<Article> Articles { get; set; } =
        new List<Article>();

    public ICollection<TherapistUnavailableDate> UnavailableDates { get; set; } =
        new List<TherapistUnavailableDate>();

    public ICollection<TherapistDocument> Documents { get; set; } =
        new List<TherapistDocument>();

    public ICollection<Workshop> Workshops { get; set; } =
        new List<Workshop>();

    public ICollection<TherapistVerificationAudit> VerificationAudits { get; set; } =
        new List<TherapistVerificationAudit>();
}