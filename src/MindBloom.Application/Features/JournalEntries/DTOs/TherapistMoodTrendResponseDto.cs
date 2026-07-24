namespace MindBloom.Application.Features
    .JournalEntries.DTOs;

public sealed class TherapistMoodTrendResponseDto
{
    public int ClientId { get; set; }

    public int Days { get; set; }

    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public double? AverageMood { get; set; }

    public string? MostFrequentEmotion
    {
        get;
        set;
    }

    public int TotalEntries { get; set; }

    public string Trend { get; set; }
        = "InsufficientData";

    public double? TrendDifference { get; set; }

    public double? PreviousAverageMood
    {
        get;
        set;
    }

    public double? RecentAverageMood
    {
        get;
        set;
    }

    public MoodTrendPointDto? BestDay
    {
        get;
        set;
    }

    public MoodTrendPointDto? HardestDay
    {
        get;
        set;
    }

    public List<MoodTrendPointDto> Points
    {
        get;
        set;
    } = [];

    public List<EmotionAnalyticsItemDto>
        Emotions
    {
        get;
        set;
    } = [];
}