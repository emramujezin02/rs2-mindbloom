namespace MindBloom.Application.Features
    .JournalEntries.DTOs;

public sealed class JournalEntryTrendQueryDto
{
    public int Days { get; set; } = 30;
}