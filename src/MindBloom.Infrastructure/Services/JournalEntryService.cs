using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.JournalEntries.DTOs;
using MindBloom.Application.Features.JournalEntries.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class JournalEntryService
    : IJournalEntryService
{
    private const int MinimumMood = 1;
    private const int MaximumMood = 5;

    private const int MaximumEmotionLength = 100;
    private const int MaximumNoteLength = 2000;

    private readonly ApplicationDbContext _context;

    public JournalEntryService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<JournalEntryResponseDto>
        CreateAsync(
            int clientUserId,
            CreateJournalEntryDto request)
    {
        Validate(
            request.Mood,
            request.Emotion,
            request.Note);

        var client =
            await GetClientAsync(
                clientUserId);

        var entry = new MoodEntry
        {
            ClientId = client.Id,
            MoodScore = request.Mood,
            Emotion = request.Emotion.Trim(),
            Notes = request.Note.Trim()
        };

        _context.MoodEntries.Add(entry);

        await _context.SaveChangesAsync();

        return MapToDto(entry);
    }

    public async Task<
        PagedResponse<JournalEntryResponseDto>>
        GetMineAsync(
            int clientUserId,
            int pageNumber,
            int pageSize)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        if (pageNumber < 1)
        {
            pageNumber = 1;
        }

        if (pageSize < 1)
        {
            pageSize = 10;
        }

        if (pageSize > 50)
        {
            pageSize = 50;
        }

        var query =
            _context.MoodEntries
                .AsNoTracking()
                .Where(x =>
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .Skip(
                    (pageNumber - 1) *
                    pageSize)
                .Take(pageSize)
                .Select(x =>
                    new JournalEntryResponseDto
                    {
                        Id = x.Id,
                        CreatedAtUtc =
                            x.CreatedAtUtc,
                        UpdatedAtUtc =
                            x.UpdatedAtUtc,
                        Mood =
                            x.MoodScore,
                        Emotion =
                            x.Emotion,
                        Note =
                            x.Notes
                    })
                .ToListAsync();

        return new PagedResponse<
            JournalEntryResponseDto>
        {
            Items = items,
            PageNumber = pageNumber,
            PageSize = pageSize,
            TotalCount = totalCount,
            TotalPages =
                (int)Math.Ceiling(
                    totalCount /
                    (double)pageSize)
        };
    }

    public async Task<JournalEntryResponseDto>
        GetByIdAsync(
            int clientUserId,
            int journalEntryId)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        var entry =
            await _context.MoodEntries
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id == journalEntryId &&
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        if (entry == null)
        {
            throw new Exception(
                "Journal entry not found.");
        }

        return MapToDto(entry);
    }

    public async Task<JournalEntryResponseDto>
        UpdateAsync(
            int clientUserId,
            int journalEntryId,
            UpdateJournalEntryDto request)
    {
        Validate(
            request.Mood,
            request.Emotion,
            request.Note);

        var client =
            await GetClientAsync(
                clientUserId);

        var entry =
            await _context.MoodEntries
                .FirstOrDefaultAsync(x =>
                    x.Id == journalEntryId &&
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        if (entry == null)
        {
            throw new Exception(
                "Journal entry not found.");
        }

        entry.MoodScore =
            request.Mood;

        entry.Emotion =
            request.Emotion.Trim();

        entry.Notes =
            request.Note.Trim();

        await _context.SaveChangesAsync();

        return MapToDto(entry);
    }

    public async Task DeleteAsync(
        int clientUserId,
        int journalEntryId)
    {
        var client =
            await GetClientAsync(
                clientUserId);

        var entry =
            await _context.MoodEntries
                .FirstOrDefaultAsync(x =>
                    x.Id == journalEntryId &&
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        if (entry == null)
        {
            throw new Exception(
                "Journal entry not found.");
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
                    clientUserId);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        return client;
    }

    private static void Validate(
        int mood,
        string emotion,
        string note)
    {
        if (mood < MinimumMood ||
            mood > MaximumMood)
        {
            throw new Exception(
                "Mood must be between 1 and 5.");
        }

        var normalizedEmotion =
            emotion?.Trim()
            ?? string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedEmotion))
        {
            throw new Exception(
                "Emotion is required.");
        }

        if (normalizedEmotion.Length >
            MaximumEmotionLength)
        {
            throw new Exception(
                "Emotion may contain at most 100 characters.");
        }

        var normalizedNote =
            note?.Trim()
            ?? string.Empty;

        if (normalizedNote.Length >
            MaximumNoteLength)
        {
            throw new Exception(
                "Note may contain at most 2000 characters.");
        }
    }

    private static JournalEntryResponseDto
        MapToDto(
            MoodEntry entry)
    {
        return new JournalEntryResponseDto
        {
            Id = entry.Id,
            CreatedAtUtc =
                entry.CreatedAtUtc,
            UpdatedAtUtc =
                entry.UpdatedAtUtc,
            Mood =
                entry.MoodScore,
            Emotion =
                entry.Emotion,
            Note =
                entry.Notes
        };
    }
}