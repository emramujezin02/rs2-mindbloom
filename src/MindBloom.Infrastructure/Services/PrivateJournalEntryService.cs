using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;
using MindBloom.Application.Features
    .PrivateJournalEntries.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class PrivateJournalEntryService
    : IPrivateJournalEntryService
{
    private readonly ApplicationDbContext
        _context;

    public PrivateJournalEntryService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PrivateJournalEntryResponseDto>
        CreateAsync(
            int clientUserId,
            CreatePrivateJournalEntryDto request)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        MoodEntry? moodEntry = null;

        if (request.MoodEntryId.HasValue)
        {
            moodEntry =
                await GetOwnedMoodEntryAsync(
                    client.Id,
                    request.MoodEntryId.Value);
        }

        var entry =
            new PrivateJournalEntry
            {
                ClientId =
                    client.Id,

                Title =
                    NormalizeTitle(
                        request.Title),

                Content =
                    NormalizeContent(
                        request.Content),

                EntryDateUtc =
                    NormalizeUtc(
                        request.EntryDateUtc),

                MoodEntryId =
                    moodEntry?.Id
            };

        _context.PrivateJournalEntries
            .Add(entry);

        await _context.SaveChangesAsync();

        return MapToDto(
            entry,
            moodEntry);
    }

    public async Task<
        PagedResponse<PrivateJournalEntryResponseDto>>
        GetMineAsync(
            int clientUserId,
            PrivateJournalEntryQueryDto query)
    {
        if (query.FromUtc.HasValue &&
            query.ToUtc.HasValue &&
            query.FromUtc.Value >
                query.ToUtc.Value)
        {
            throw new BusinessException(
                "Start date cannot be later than end date.");
        }

        var pagination =
            PaginationHelper.Normalize(
                query.PageNumber,
                query.PageSize);

        var client =
            await GetClientAsync(
                clientUserId);

        var entries =
            _context.PrivateJournalEntries
                .AsNoTracking()
                .Include(x =>
                    x.MoodEntry)
                .Where(x =>
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        var normalizedSearch =
            query.Search?.Trim();

        if (!string.IsNullOrWhiteSpace(
                normalizedSearch))
        {
            entries =
                entries.Where(x =>
                    x.Title.Contains(
                        normalizedSearch) ||
                    x.Content.Contains(
                        normalizedSearch));
        }

        if (query.FromUtc.HasValue)
        {
            var fromUtc =
                NormalizeUtc(
                    query.FromUtc.Value);

            entries =
                entries.Where(x =>
                    x.EntryDateUtc >= fromUtc);
        }

        if (query.ToUtc.HasValue)
        {
            var toUtc =
                NormalizeUtc(
                    query.ToUtc.Value);

            entries =
                entries.Where(x =>
                    x.EntryDateUtc <= toUtc);
        }

        var totalCount =
            await entries.CountAsync();

        var items =
            await entries
                .OrderByDescending(x =>
                    x.EntryDateUtc)
                .ThenByDescending(x =>
                    x.CreatedAtUtc)
                .Skip(
                    pagination.Skip)
                .Take(
                    pagination.PageSize)
                .ToListAsync();

        var responseItems =
            items
                .Select(x =>
                    MapToDto(
                        x,
                        x.MoodEntry))
                .ToList();

        return PagedResponse<
                PrivateJournalEntryResponseDto>
            .Create(
                responseItems,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<PrivateJournalEntryResponseDto>
        GetByIdAsync(
            int clientUserId,
            int privateJournalEntryId)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        var entry =
            await _context.PrivateJournalEntries
                .AsNoTracking()
                .Include(x =>
                    x.MoodEntry)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        privateJournalEntryId &&
                    x.ClientId ==
                        client.Id &&
                    !x.IsDeleted);

        if (entry == null)
        {
            throw new NotFoundException(
                "Private journal entry not found.");
        }

        return MapToDto(
            entry,
            entry.MoodEntry);
    }

    public async Task<PrivateJournalEntryResponseDto>
        UpdateAsync(
            int clientUserId,
            int privateJournalEntryId,
            UpdatePrivateJournalEntryDto request)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        var entry =
            await _context.PrivateJournalEntries
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        privateJournalEntryId &&
                    x.ClientId ==
                        client.Id &&
                    !x.IsDeleted);

        if (entry == null)
        {
            throw new NotFoundException(
                "Private journal entry not found.");
        }

        MoodEntry? moodEntry = null;

        if (request.MoodEntryId.HasValue)
        {
            moodEntry =
                await GetOwnedMoodEntryAsync(
                    client.Id,
                    request.MoodEntryId.Value);
        }

        entry.Title =
            NormalizeTitle(
                request.Title);

        entry.Content =
            NormalizeContent(
                request.Content);

        entry.EntryDateUtc =
            NormalizeUtc(
                request.EntryDateUtc);

        entry.MoodEntryId =
            moodEntry?.Id;

        await _context.SaveChangesAsync();

        return MapToDto(
            entry,
            moodEntry);
    }

    public async Task DeleteAsync(
        int clientUserId,
        int privateJournalEntryId)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        var entry =
            await _context.PrivateJournalEntries
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        privateJournalEntryId &&
                    x.ClientId ==
                        client.Id &&
                    !x.IsDeleted);

        if (entry == null)
        {
            throw new NotFoundException(
                "Private journal entry not found.");
        }

        entry.IsDeleted = true;

        await _context.SaveChangesAsync();
    }

    private async Task<Client>
        GetClientAsync(
            int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                        clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        return client;
    }

    private async Task<MoodEntry>
        GetOwnedMoodEntryAsync(
            int clientId,
            int moodEntryId)
    {
        var moodEntry =
            await _context.MoodEntries
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id == moodEntryId &&
                    x.ClientId == clientId &&
                    !x.IsDeleted);

        if (moodEntry == null)
        {
            throw new NotFoundException(
                "Mood entry not found.");
        }

        return moodEntry;
    }

    private static PrivateJournalEntryResponseDto
        MapToDto(
            PrivateJournalEntry entry,
            MoodEntry? moodEntry)
    {
        return new PrivateJournalEntryResponseDto
        {
            Id =
                entry.Id,

            Title =
                entry.Title,

            Content =
                entry.Content,

            EntryDateUtc =
                entry.EntryDateUtc,

            CreatedAtUtc =
                entry.CreatedAtUtc,

            UpdatedAtUtc =
                entry.UpdatedAtUtc,

            MoodEntryId =
                entry.MoodEntryId,

            Mood =
                moodEntry?.MoodScore,

            Emotions =
                SplitEmotions(
                    moodEntry?.Emotion)
        };
    }

    private static string NormalizeTitle(
        string title)
    {
        return title.Trim();
    }

    private static string NormalizeContent(
        string content)
    {
        return content.Trim();
    }

    private static DateTime NormalizeUtc(
        DateTime value)
    {
        if (value.Kind ==
            DateTimeKind.Utc)
        {
            return value;
        }

        if (value.Kind ==
            DateTimeKind.Local)
        {
            return value.ToUniversalTime();
        }

        return DateTime.SpecifyKind(
            value,
            DateTimeKind.Utc);
    }

    private static List<string>
        SplitEmotions(
            string? emotions)
    {
        if (string.IsNullOrWhiteSpace(
                emotions))
        {
            return [];
        }

        return emotions
            .Split(
                ',',
                StringSplitOptions
                    .RemoveEmptyEntries |
                StringSplitOptions
                    .TrimEntries)
            .Where(x =>
                !string.IsNullOrWhiteSpace(x))
            .Distinct(
                StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}