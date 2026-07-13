namespace MindBloom.Domain.Entities;

public class Client : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();
    public ICollection<WorkshopRegistration> WorkshopRegistrations{ get; set; } = new List<WorkshopRegistration>();
    public ICollection<MoodEntry> MoodEntries { get; set; } = new List<MoodEntry>();
}