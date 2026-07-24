namespace MindBloom.Application.Features.JournalEntries.DTOs;

public class UpdateJournalEntryDto
{
    public int Mood { get; set; }

    public List<string> Emotions { get; set; } = [];

    public string Note { get; set; } =
        string.Empty;
}