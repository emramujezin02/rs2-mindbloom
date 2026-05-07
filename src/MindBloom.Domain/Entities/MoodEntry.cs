namespace MindBloom.Domain.Entities;

public class MoodEntry : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public int MoodScore { get; set; }

    public string Notes { get; set; } = string.Empty;
}