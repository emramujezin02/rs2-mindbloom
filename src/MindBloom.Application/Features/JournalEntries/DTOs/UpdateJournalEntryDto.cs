namespace MindBloom.Application.Features.JournalEntries.DTOs;

public class UpdateJournalEntryDto
{
    public int Mood { get; set; }

    public string Emotion { get; set; } =
        string.Empty;

    public string Note { get; set; } =
        string.Empty;
}