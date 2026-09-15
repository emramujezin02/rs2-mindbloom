namespace MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;

public sealed class PrivateJournalEntryResponseDto
{
    public int Id { get; set; }

    public string Title { get; set; } =
        string.Empty;

    public string Content { get; set; } =
        string.Empty;

    public DateTime EntryDateUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public int? MoodEntryId { get; set; }

    public int? Mood { get; set; }

    public List<string> Emotions { get; set; } = [];
}