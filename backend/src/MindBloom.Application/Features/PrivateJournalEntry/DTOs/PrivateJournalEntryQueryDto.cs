namespace MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;

public sealed class PrivateJournalEntryQueryDto
{
    public string? Search { get; set; }

    public DateTime? FromUtc { get; set; }

    public DateTime? ToUtc { get; set; }

    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;
}