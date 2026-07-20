using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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
            throw new NotFoundException(
                "Journal entry not found.");
        }

        entry.IsDeleted = true;

        await _context.SaveChangesAsync();
    }

    public async Task<
    PagedResponse<TherapistMoodEntryResponseDto>>
    GetClientHistoryForTherapistAsync(
        int therapistUserId,
        int clientId,
        int pageNumber,
        int pageSize)
    {
        await EnsureTherapistOwnsClientAsync(
            therapistUserId,
            clientId);

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
                    x.ClientId == clientId &&
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
                    new TherapistMoodEntryResponseDto
                    {
                        Id = x.Id,
                        CreatedAtUtc =
                            x.CreatedAtUtc,
                        Mood =
                            x.MoodScore,
                        Emotion =
                            x.Emotion
                    })
                .ToListAsync();

        return new PagedResponse<
            TherapistMoodEntryResponseDto>
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

    public async Task<
        TherapistMoodTrendResponseDto>
        GetClientTrendForTherapistAsync(
            int therapistUserId,
            int clientId,
            int days)
    {
        await EnsureTherapistOwnsClientAsync(
            therapistUserId,
            clientId);

        if (days < 1)
        {
            days = 7;
        }

        if (days > 365)
        {
            days = 365;
        }

        var fromUtc =
            DateTime.UtcNow.Date
                .AddDays(-(days - 1));

        var entries =
            await _context.MoodEntries
                .AsNoTracking()
                .Where(x =>
                    x.ClientId == clientId &&
                    !x.IsDeleted &&
                    x.CreatedAtUtc >= fromUtc)
                .Select(x => new
                {
                    x.CreatedAtUtc,
                    x.MoodScore,
                    x.Emotion
                })
                .ToListAsync();

        var points =
            entries
                .GroupBy(x =>
                    x.CreatedAtUtc.Date)
                .OrderBy(x => x.Key)
                .Select(group =>
                    new MoodTrendPointDto
                    {
                        DateUtc =
                            DateTime.SpecifyKind(
                                group.Key,
                                DateTimeKind.Utc),
                        AverageMood =
                            Math.Round(
                                group.Average(x =>
                                    x.MoodScore),
                                2),
                        EntryCount =
                            group.Count()
                    })
                .ToList();

        var mostFrequentEmotion =
            entries
                .Where(x =>
                    !string.IsNullOrWhiteSpace(
                        x.Emotion))
                .GroupBy(x =>
                    x.Emotion.Trim(),
                    StringComparer.OrdinalIgnoreCase)
                .OrderByDescending(group =>
                    group.Count())
                .ThenBy(group =>
                    group.Key)
                .Select(group =>
                    group.Key)
                .FirstOrDefault();

        return new TherapistMoodTrendResponseDto
        {
            ClientId = clientId,
            Days = days,
            AverageMood =
                entries.Count == 0
                    ? null
                    : Math.Round(
                        entries.Average(x =>
                            x.MoodScore),
                        2),
            MostFrequentEmotion =
                mostFrequentEmotion,
            TotalEntries =
                entries.Count,
            Points =
                points
        };
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
            throw new NotFoundException(
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

    private async Task
    EnsureTherapistOwnsClientAsync(
        int therapistUserId,
        int clientId)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                    therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var clientExists =
            await _context.Clients
                .AsNoTracking()
                .AnyAsync(x =>
                    x.Id == clientId);

        if (!clientExists)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var hasClientRelationship =
            await _context.Appointments
                .AsNoTracking()
                .AnyAsync(x =>
                    x.TherapistId ==
                        therapist.Id &&
                    x.ClientId ==
                        clientId &&
                    !x.IsDeleted);

        if (!hasClientRelationship)
        {
            throw new UnauthorizedAccessException(
                "You do not have permission to access this client's emotional tracker.");
        }
    }
}