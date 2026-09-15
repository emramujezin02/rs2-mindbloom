using MindBloom.Application.Common.Models;
using MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;

namespace MindBloom.Application.Features
    .PrivateJournalEntries.Interfaces;

public interface IPrivateJournalEntryService
{
    Task<PrivateJournalEntryResponseDto>
        CreateAsync(
            int clientUserId,
            CreatePrivateJournalEntryDto request);

    Task<PagedResponse<PrivateJournalEntryResponseDto>>
        GetMineAsync(
            int clientUserId,
            PrivateJournalEntryQueryDto query);

    Task<PrivateJournalEntryResponseDto>
        GetByIdAsync(
            int clientUserId,
            int privateJournalEntryId);

    Task<PrivateJournalEntryResponseDto>
        UpdateAsync(
            int clientUserId,
            int privateJournalEntryId,
            UpdatePrivateJournalEntryDto request);

    Task DeleteAsync(
        int clientUserId,
        int privateJournalEntryId);
}