namespace MindBloom.Application.Features.JournalEntries.DTOs;

public class TherapistMoodEntryResponseDto
{
    public int Id { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public int Mood { get; set; }

    public string Emotion { get; set; } =
        string.Empty;
}