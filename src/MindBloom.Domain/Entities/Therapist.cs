namespace MindBloom.Domain.Entities;

public class Therapist : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public string Biography { get; set; } = string.Empty;

    public int YearsOfExperience { get; set; }

    public decimal SessionPrice { get; set; }

    public bool OffersOnlineSessions { get; set; }

    public double AverageRating { get; set; }

    public ICollection<Review> Reviews { get; set; } = new List<Review>();

    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();
}