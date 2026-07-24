using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.JournalEntries.DTOs;
using MindBloom.Application.Features.JournalEntries.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Application.Common.Pagination;

namespace MindBloom.Infrastructure.Services;

public class JournalEntryService
    : IJournalEntryService
{

    private readonly ApplicationDbContext _context;
    private static readonly HashSet<string>
    AllowedEmotions =
        new(
            StringComparer.OrdinalIgnoreCase)
        {
            "Happy",
            "Calm",
            "Hopeful",
            "Excited",
            "Grateful",
            "Sad",
            "Anxious",
            "Angry",
            "Lonely",
            "Tired",
            "Stressed",
            "Confused"
        };
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
        ValidateRequest(
            request.Mood,
            request.Emotions,
            request.Note);

        var client =
            await GetClientAsync(
                clientUserId);

        var entry = new MoodEntry
        {
            ClientId = client.Id,
            MoodScore = request.Mood,
            Emotion = NormalizeEmotions(
                request.Emotions),
            Notes = NormalizeNote(
                request.Note)
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
         int pageSize,
         DateTime? fromUtc,
         DateTime? toUtc)
    {
        if (fromUtc.HasValue &&
            toUtc.HasValue &&
            fromUtc.Value > toUtc.Value)
        {
            throw new BusinessException(
                "Start date cannot be later than end date.");
        }

        var pagination =
            PaginationHelper.Normalize(
                pageNumber,
                pageSize);

        var client =
            await GetClientAsync(
                clientUserId);

        var query =
            _context.MoodEntries
                .AsNoTracking()
                .Where(x =>
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        if (fromUtc.HasValue)
        {
            query = query.Where(x =>
                x.CreatedAtUtc >=
                fromUtc.Value);
        }

        if (toUtc.HasValue)
        {
            query = query.Where(x =>
                x.CreatedAtUtc <=
                toUtc.Value);
        }

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .Skip(pagination.Skip)
                .Take(pagination.PageSize)
                .ToListAsync();

        var responseItems =
            items
                .Select(MapToDto)
                .ToList();

        return PagedResponse<
                JournalEntryResponseDto>
            .Create(
                responseItems,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
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
        ValidateRequest(
            request.Mood,
            request.Emotions,
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
            NormalizeEmotions(
                request.Emotions);

        entry.Notes =
            NormalizeNote(
                request.Note);

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
        var pagination =
    PaginationHelper.Normalize(
        pageNumber,
        pageSize);

        await EnsureTherapistOwnsClientAsync(
            therapistUserId,
            clientId);



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
    pagination.Skip)
.Take(
    pagination.PageSize)
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

        return PagedResponse<
                TherapistMoodEntryResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
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

        

        var toUtc =
            DateTime.UtcNow.Date
                .AddDays(1)
                .AddTicks(-1);

        var fromUtc =
            DateTime.UtcNow.Date
                .AddDays(-(days - 1));

        var entries =
            await _context.MoodEntries
                .AsNoTracking()
                .Where(x =>
                    x.ClientId == clientId &&
                    !x.IsDeleted &&
                    x.CreatedAtUtc >= fromUtc &&
                    x.CreatedAtUtc <= toUtc)
                .Select(x => new
                {
                    x.CreatedAtUtc,
                    x.MoodScore,
                    x.Emotion
                })
                .OrderBy(x => x.CreatedAtUtc)
                .ToListAsync();

        var points =
            entries
                .GroupBy(x =>
                    x.CreatedAtUtc.Date)
                .OrderBy(group =>
                    group.Key)
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

        var emotionGroups =
            entries
                .SelectMany(x =>
                    SplitEmotions(x.Emotion))
                .GroupBy(
                    emotion => emotion,
                    StringComparer.OrdinalIgnoreCase)
                .Select(group => new
                {
                    Emotion = group.Key,
                    Count = group.Count()
                })
                .OrderByDescending(x =>
                    x.Count)
                .ThenBy(x =>
                    x.Emotion)
                .ToList();


        var emotionEntryCount =
            emotionGroups.Sum(x => x.Count);

        var emotionAnalytics =
            emotionGroups
                .Select(item =>
                    new EmotionAnalyticsItemDto
                    {
                        Emotion =
                            item.Emotion,

                        Count =
                            item.Count,

                        Percentage =
                            emotionEntryCount == 0
                                ? 0
                                : Math.Round(
                                    item.Count * 100.0 /
                                    emotionEntryCount,
                                    2)
                    })
                .ToList();

        var mostFrequentEmotion =
            emotionGroups
                .Select(x => x.Emotion)
                .FirstOrDefault();

        var trendResult =
            CalculateMoodTrend(points);

        return new TherapistMoodTrendResponseDto
        {
            ClientId = clientId,

            Days = days,

            FromUtc = fromUtc,

            ToUtc = toUtc,

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

            Trend =
                trendResult.Trend,

            TrendDifference =
                trendResult.Difference,

            PreviousAverageMood =
                trendResult.PreviousAverage,

            RecentAverageMood =
                trendResult.RecentAverage,

            Points =
                points,

            Emotions =
                emotionAnalytics
        };
    }

    private static MoodTrendCalculation
        CalculateMoodTrend(
            IReadOnlyList<MoodTrendPointDto>
                points)
    {
        if (points.Count < 2)
        {
            return new MoodTrendCalculation
            {
                Trend =
                    "InsufficientData"
            };
        }

        var midpoint =
            points.Count / 2;

        if (midpoint < 1)
        {
            return new MoodTrendCalculation
            {
                Trend =
                    "InsufficientData"
            };
        }

        var previousPoints =
            points
                .Take(midpoint)
                .ToList();

        var recentPoints =
            points
                .Skip(midpoint)
                .ToList();

        if (previousPoints.Count == 0 ||
            recentPoints.Count == 0)
        {
            return new MoodTrendCalculation
            {
                Trend =
                    "InsufficientData"
            };
        }

        var previousAverage =
            Math.Round(
                previousPoints
                    .Average(x =>
                        x.AverageMood),
                2);

        var recentAverage =
            Math.Round(
                recentPoints
                    .Average(x =>
                        x.AverageMood),
                2);

        var difference =
            Math.Round(
                recentAverage -
                previousAverage,
                2);

        const double stableThreshold =
            0.15;

        var trend =
            difference > stableThreshold
                ? "Improving"
                : difference <
                  -stableThreshold
                    ? "Declining"
                    : "Stable";

        return new MoodTrendCalculation
        {
            Trend = trend,

            Difference = difference,

            PreviousAverage =
                previousAverage,

            RecentAverage =
                recentAverage
        };
    }

    private sealed class MoodTrendCalculation
    {
        public string Trend { get; set; }
            = "InsufficientData";

        public double? Difference { get; set; }

        public double? PreviousAverage
        {
            get;
            set;
        }

        public double? RecentAverage
        {
            get;
            set;
        }
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
            Emotions =
                SplitEmotions(
                    entry.Emotion),
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

    private static void ValidateRequest(
    int mood,
    IEnumerable<string>? emotions,
    string? note)
    {
        if (mood < 1 || mood > 5)
        {
            throw new BusinessException(
                "Mood must be between 1 and 5.");
        }

        var normalizedEmotions =
            NormalizeEmotionList(emotions);

        if (normalizedEmotions.Count == 0)
        {
            throw new BusinessException(
                "At least one emotion must be selected.");
        }

        if (normalizedEmotions.Count > 5)
        {
            throw new BusinessException(
                "You may select at most 5 emotions.");
        }

        var invalidEmotion =
            normalizedEmotions
                .FirstOrDefault(x =>
                    !AllowedEmotions.Contains(x));

        if (invalidEmotion != null)
        {
            throw new BusinessException(
                $"Emotion '{invalidEmotion}' is not supported.");
        }

        if (!string.IsNullOrWhiteSpace(note) &&
            note.Trim().Length > 500)
        {
            throw new BusinessException(
                "Note may contain at most 500 characters.");
        }
    }

    private static string NormalizeEmotions(
        IEnumerable<string>? emotions)
    {
        return string.Join(
            ",",
            NormalizeEmotionList(emotions));
    }

    private static List<string>
        NormalizeEmotionList(
            IEnumerable<string>? emotions)
    {
        return emotions?
            .Where(x =>
                !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(
                StringComparer.OrdinalIgnoreCase)
            .ToList()
            ?? [];
    }

    private static List<string> SplitEmotions(
        string? emotions)
    {
        if (string.IsNullOrWhiteSpace(emotions))
        {
            return [];
        }

        return emotions
            .Split(
                ',',
                StringSplitOptions.RemoveEmptyEntries |
                StringSplitOptions.TrimEntries)
            .Distinct(
                StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static string NormalizeNote(
        string? note)
    {
        return string.IsNullOrWhiteSpace(note)
            ? string.Empty
            : note.Trim();
    }
}