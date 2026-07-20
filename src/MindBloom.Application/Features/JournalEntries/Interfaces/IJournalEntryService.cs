using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.JournalEntries.DTOs;

namespace MindBloom.Application.Features.JournalEntries.Interfaces;

public interface IJournalEntryService
{
    Task<JournalEntryResponseDto> CreateAsync(
        int clientUserId,
        CreateJournalEntryDto request);

    Task<PagedResponse<JournalEntryResponseDto>>
        GetMineAsync(
            int clientUserId,
            int pageNumber,
            int pageSize);

    Task<JournalEntryResponseDto> GetByIdAsync(
        int clientUserId,
        int journalEntryId);

    Task<JournalEntryResponseDto> UpdateAsync(
        int clientUserId,
        int journalEntryId,
        UpdateJournalEntryDto request);

    Task DeleteAsync(
        int clientUserId,
        int journalEntryId);

    Task<PagedResponse<TherapistMoodEntryResponseDto>>
        GetClientHistoryForTherapistAsync(
            int therapistUserId,
            int clientId,
            int pageNumber,
            int pageSize);

    Task<TherapistMoodTrendResponseDto>
        GetClientTrendForTherapistAsync(
            int therapistUserId,
            int clientId,
            int days);
}