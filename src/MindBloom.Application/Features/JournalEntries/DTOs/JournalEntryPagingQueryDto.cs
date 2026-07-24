namespace MindBloom.Application.Features
    .JournalEntries.DTOs;

public sealed class JournalEntryPagingQueryDto
{
    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 10;

    public DateTime? FromUtc { get; set; }

    public DateTime? ToUtc { get; set; }
}