namespace MindBloom.Domain.Entities;

public class PrivateJournalEntry : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public string Title { get; set; } =
        string.Empty;

    public string Content { get; set; } =
        string.Empty;

    public DateTime EntryDateUtc { get; set; }

    public int? MoodEntryId { get; set; }

    public MoodEntry? MoodEntry { get; set; }
}