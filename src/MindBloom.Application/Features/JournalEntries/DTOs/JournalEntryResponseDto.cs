namespace MindBloom.Application.Features.JournalEntries.DTOs;

public class JournalEntryResponseDto
{
    public int Id { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public int Mood { get; set; }

    public List<string> Emotions { get; set; } = [];

    public string Note { get; set; } =
        string.Empty;
}