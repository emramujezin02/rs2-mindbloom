namespace MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;

public sealed class UpdatePrivateJournalEntryDto
{
    public string Title { get; set; } =
        string.Empty;

    public string Content { get; set; } =
        string.Empty;

    public DateTime EntryDateUtc { get; set; }

    public int? MoodEntryId { get; set; }
}