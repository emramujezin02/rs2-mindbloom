namespace MindBloom.Application.Features
    .JournalEntries.DTOs;

public sealed class EmotionAnalyticsItemDto
{
    public string Emotion { get; set; }
        = string.Empty;

    public int Count { get; set; }

    public double Percentage { get; set; }
}