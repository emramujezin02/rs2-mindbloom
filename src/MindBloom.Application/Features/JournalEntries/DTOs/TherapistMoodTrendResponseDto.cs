namespace MindBloom.Application.Features.JournalEntries.DTOs;

public class TherapistMoodTrendResponseDto
{
    public int ClientId { get; set; }

    public int Days { get; set; }

    public double? AverageMood { get; set; }

    public string? MostFrequentEmotion { get; set; }

    public int TotalEntries { get; set; }

    public List<MoodTrendPointDto> Points { get; set; } =
        [];
}