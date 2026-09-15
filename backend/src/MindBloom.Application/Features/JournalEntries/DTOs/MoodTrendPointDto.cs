namespace MindBloom.Application.Features.JournalEntries.DTOs;

public class MoodTrendPointDto
{
    public DateTime DateUtc { get; set; }

    public double AverageMood { get; set; }

    public int EntryCount { get; set; }
}