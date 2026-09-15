namespace MindBloom.Application.Features
    .JournalEntries.DTOs;

public sealed class JournalEntryAnalyticsQueryDto
{
    public DateTime? FromUtc { get; set; }

    public DateTime? ToUtc { get; set; }
}