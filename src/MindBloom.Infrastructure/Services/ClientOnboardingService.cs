using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application
    .Features.ClientOnboarding.DTOs;
using MindBloom.Application
    .Features.ClientOnboarding.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure
    .Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class ClientOnboardingService
    : IClientOnboardingService
{
    private readonly ApplicationDbContext
        _context;

    public ClientOnboardingService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<ClientOnboardingDto>
        GetAsync(
            int userId)
    {
        var client =
            await _context.Clients
                .AsNoTracking()
                .Include(x =>
                    x.PreferredTherapyApproaches)
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        return MapToDto(client);
    }

    public async Task<ClientOnboardingDto>
        SaveAsync(
            int userId,
            SaveClientOnboardingDto request)
    {
        var client =
            await _context.Clients
                .Include(x =>
                    x.PreferredTherapyApproaches)
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        var therapyApproachIds =
            request
                .PreferredTherapyApproachIds
                .Where(x => x > 0)
                .Distinct()
                .ToList();

        var existingApproachIds =
            await _context.TherapyApproaches
                .AsNoTracking()
                .Where(x =>
                    therapyApproachIds.Contains(
                        x.Id) &&
                    x.IsActive &&
                    !x.IsDeleted)
                .Select(x => x.Id)
                .ToListAsync();

        if (existingApproachIds.Count !=
            therapyApproachIds.Count)
        {
            throw new BadRequestException(
                "One or more selected therapy approaches are not available.");
        }

        client.AssessmentFocusAreas =
            SerializeTextValues(
                request.AssessmentFocusAreas);

        client.PreferredTherapistGender =
            NormalizeNullableText(
                request
                    .PreferredTherapistGender);

        client.PreferredSessionType =
            NormalizeNullableText(
                request.PreferredSessionType);

        client.PreferredLanguages =
            SerializeTextValues(
                request.PreferredLanguages);

        client.MinimumPricePerSession =
            request.MinimumPricePerSession;

        client.MaximumPricePerSession =
            request.MaximumPricePerSession;

        client.Location =
            NormalizeNullableText(
                request.Location);

        client.PreferredDays =
            SerializeDays(
                request.PreferredDays);

        if (request.CompleteOnboarding)
        {
            client.HasCompletedOnboarding =
                true;

            client.OnboardingCompletedAtUtc ??=
                DateTime.UtcNow;
        }

        var selectedIds =
            existingApproachIds.ToHashSet();

        var relationsToDelete =
            client.PreferredTherapyApproaches
                .Where(x =>
                    !selectedIds.Contains(
                        x.TherapyApproachId))
                .ToList();

        foreach (var relation
                 in relationsToDelete)
        {
            _context
                .Set<ClientTherapyApproach>()
                .Remove(relation);
        }

        var currentIds =
            client.PreferredTherapyApproaches
                .Where(x =>
                    !relationsToDelete.Contains(x))
                .Select(x =>
                    x.TherapyApproachId)
                .ToHashSet();

        foreach (var approachId
                 in selectedIds)
        {
            if (currentIds.Contains(
                    approachId))
            {
                continue;
            }

            client.PreferredTherapyApproaches
                .Add(
                    new ClientTherapyApproach
                    {
                        ClientId =
                            client.Id,

                        TherapyApproachId =
                            approachId
                    });
        }

        await _context.SaveChangesAsync();

        return await GetAsync(userId);
    }

    private static ClientOnboardingDto
        MapToDto(
            Client client)
    {
        return new ClientOnboardingDto
        {
            HasCompletedOnboarding =
                client
                    .HasCompletedOnboarding,

            CompletedAtUtc =
                client
                    .OnboardingCompletedAtUtc,

            AssessmentFocusAreas =
                SplitTextValues(
                    client
                        .AssessmentFocusAreas),

            PreferredTherapistGender =
                client
                    .PreferredTherapistGender,

            PreferredSessionType =
                client
                    .PreferredSessionType,

            PreferredLanguages =
                SplitTextValues(
                    client
                        .PreferredLanguages),

            MinimumPricePerSession =
                client
                    .MinimumPricePerSession,

            MaximumPricePerSession =
                client
                    .MaximumPricePerSession,

            Location =
                client.Location,

            PreferredDays =
                SplitDays(
                    client.PreferredDays),

            PreferredTherapyApproachIds =
                client
                    .PreferredTherapyApproaches
                    .Where(x =>
                        !x.IsDeleted)
                    .Select(x =>
                        x.TherapyApproachId)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToList()
        };
    }

    private static string?
        NormalizeNullableText(
            string? value)
    {
        return string.IsNullOrWhiteSpace(
                value)
            ? null
            : value.Trim();
    }

    private static string?
        SerializeTextValues(
            IEnumerable<string>? values)
    {
        if (values == null)
        {
            return null;
        }

        var normalized =
            values
                .Where(x =>
                    !string.IsNullOrWhiteSpace(
                        x))
                .Select(x =>
                    x.Trim())
                .Distinct(
                    StringComparer
                        .OrdinalIgnoreCase)
                .OrderBy(x => x)
                .ToList();

        return normalized.Count == 0
            ? null
            : string.Join(
                "|",
                normalized);
    }

    private static List<string>
        SplitTextValues(
            string? value)
    {
        if (string.IsNullOrWhiteSpace(
                value))
        {
            return [];
        }

        return value
            .Split(
                '|',
                StringSplitOptions
                    .RemoveEmptyEntries |
                StringSplitOptions
                    .TrimEntries)
            .Distinct(
                StringComparer
                    .OrdinalIgnoreCase)
            .ToList();
    }

    private static string?
        SerializeDays(
            IEnumerable<DayOfWeek>? days)
    {
        if (days == null)
        {
            return null;
        }

        var values =
            days
                .Distinct()
                .OrderBy(x => (int)x)
                .Select(x =>
                    ((int)x).ToString())
                .ToList();

        return values.Count == 0
            ? null
            : string.Join(",", values);
    }

    private static List<DayOfWeek>
        SplitDays(
            string? value)
    {
        if (string.IsNullOrWhiteSpace(
                value))
        {
            return [];
        }

        return value
            .Split(
                ',',
                StringSplitOptions
                    .RemoveEmptyEntries |
                StringSplitOptions
                    .TrimEntries)
            .Select(x =>
                int.TryParse(
                    x,
                    out var day)
                    ? day
                    : -1)
            .Where(x =>
                x >= 0 &&
                x <= 6)
            .Distinct()
            .OrderBy(x => x)
            .Select(x =>
                (DayOfWeek)x)
            .ToList();
    }
}