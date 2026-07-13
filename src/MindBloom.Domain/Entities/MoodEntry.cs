namespace MindBloom.Domain.Entities;

public class MoodEntry : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public int MoodScore { get; set; }

    public string Emotion { get; set; } =
        string.Empty;

    public string Notes { get; set; } =
        string.Empty;
}