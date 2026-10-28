using MindBloom.Infrastructure.Serialization;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application
    .Features.ClientOnboarding.DTOs;
using MindBloom.Application
    .Features.ClientOnboarding.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure
    .Persistence.Context;
using MindBloom.Domain.Enums;
using MindBloom.Shared.Constants;

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
            int userId,
            CancellationToken cancellationToken =
                default)
    {
        var client =
            await _context.Clients
                .AsNoTracking()
                .Where(x =>
                    x.UserId == userId &&
                    !x.IsDeleted)
                .Select(x =>
                    new
                    {
                        x.Id,
                        x.HasCompletedOnboarding,
                        x.OnboardingCompletedAtUtc,
                        x.AssessmentFocusAreas,
                        x.PreferredTherapistGender,
                        x.PreferredSessionType,
                        x.PreferredLanguages,
                        x.MinimumPricePerSession,
                        x.MaximumPricePerSession,
                        x.Location,
                        x.PreferredDays
                    })
                .FirstOrDefaultAsync(
                    cancellationToken);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        var dto =
            new ClientOnboardingDto
            {
                HasCompletedOnboarding =
                    client.HasCompletedOnboarding,

                CompletedAtUtc =
                    client.OnboardingCompletedAtUtc,

                AssessmentFocusAreas =
                    SplitTextValues(
                        client.AssessmentFocusAreas),

                PreferredTherapistGender =
                    client.PreferredTherapistGender,

                PreferredSessionType =
                    client.PreferredSessionType,

                PreferredLanguages =
                    SplitTextValues(
                        client.PreferredLanguages),

                MinimumPricePerSession =
                    client.MinimumPricePerSession,

                MaximumPricePerSession =
                    client.MaximumPricePerSession,

                Location =
                    client.Location,

                PreferredDays =
                    SplitDays(
                        client.PreferredDays),

                PreferredSpecializationIds = await _context.ClientSpecializations.AsNoTracking()
                    .Where(x => x.ClientId == client.Id && !x.IsDeleted)
                    .Select(x => x.TherapistSpecializationId).Distinct().OrderBy(x => x).ToListAsync(cancellationToken),

                PreferredTherapyApproachIds =
                    await _context
                        .Set<ClientTherapyApproach>()
                        .AsNoTracking()
                        .Where(x =>
                            x.ClientId == client.Id &&
                            !x.IsDeleted)
                        .Select(x =>
                            x.TherapyApproachId)
                        .Distinct()
                        .OrderBy(x => x)
                        .ToListAsync(
                            cancellationToken)
            };

        var sensitiveConsent =
            await _context.UserConsents
                .AsNoTracking()
                .Where(x =>
                    x.UserId == userId &&
                    x.ConsentType ==
                        UserConsentType
                            .SensitiveDataProcessing &&
                    x.IsAccepted &&
                    !x.IsDeleted)
                .OrderByDescending(x =>
                    x.AcceptedAtUtc)
                .FirstOrDefaultAsync(
                    cancellationToken);

        dto.HasAcceptedSensitiveDataProcessing =
            sensitiveConsent != null;

        dto.SensitiveDataProcessingVersion =
            sensitiveConsent?
                .DocumentVersion;

        dto.SensitiveDataProcessingAcceptedAtUtc =
            sensitiveConsent?
                .AcceptedAtUtc;

        dto.SensitiveDataUsageExplanation =
            ConsentDocumentConstants
                .SensitiveDataUsageExplanation;

        dto.CurrentSensitiveDataProcessingVersion =
    ConsentDocumentConstants
        .SensitiveDataProcessingVersion;

        return dto;
    }

    public async Task<ClientOnboardingDto>
        SaveAsync(
            int userId,
            SaveClientOnboardingDto request,
            CancellationToken cancellationToken =
                default)
    {
        var client =
            await _context.Clients
                .Include(x => x.PreferredSpecializations)
                .Include(x =>
                    x.PreferredTherapyApproaches)
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    !x.IsDeleted,
                    cancellationToken);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        var containsSensitiveAssessmentData =
            request.AssessmentFocusAreas != null &&
            request.AssessmentFocusAreas
                .Any(x =>
                    !string.IsNullOrWhiteSpace(
                        x));

        var currentSensitiveConsent =
            await _context.UserConsents
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    x.ConsentType ==
                        UserConsentType
                            .SensitiveDataProcessing &&
                    x.DocumentVersion ==
                        ConsentDocumentConstants
                            .SensitiveDataProcessingVersion &&
                    x.IsAccepted &&
                    !x.IsDeleted,
                    cancellationToken);

        var alreadyAcceptedCurrentConsent =
            currentSensitiveConsent != null;

        if (containsSensitiveAssessmentData &&
            !alreadyAcceptedCurrentConsent)
        {
            if (!request.AcceptSensitiveDataProcessing)
            {
                throw new BadRequestException(
                    "Consent for processing sensitive assessment data is required.");
            }

            if (!string.Equals(
                    request.SensitiveDataProcessingVersion,
                    ConsentDocumentConstants
                        .SensitiveDataProcessingVersion,
                    StringComparison.Ordinal))
            {
                throw new BadRequestException(
                    "The sensitive data processing consent version is no longer current.");
            }
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
                .ToListAsync(
                    cancellationToken);

        if (existingApproachIds.Count !=
            therapyApproachIds.Count)
        {
            throw new BadRequestException(
                "One or more selected therapy approaches are not available.");
        }

        List<int>? specializationIds = request.PreferredSpecializationIds?.Distinct().ToList();
        if (specializationIds != null)
        {
            if (specializationIds.Count > 10 || specializationIds.Any(x => x <= 0))
                throw new BadRequestException("Select up to 10 valid specializations.");
            var validIds = await _context.TherapistSpecializations.AsNoTracking()
                .Where(x => specializationIds.Contains(x.Id) && x.IsActive && !x.IsDeleted)
                .Select(x => x.Id).ToListAsync(cancellationToken);
            if (validIds.Count != specializationIds.Count)
                throw new BadRequestException("One or more selected specializations are invalid or inactive.");
        }

        if (specializationIds != null)
        {
            var removed = client.PreferredSpecializations.Where(x => !specializationIds.Contains(x.TherapistSpecializationId)).ToList();
            _context.ClientSpecializations.RemoveRange(removed);
            foreach (var id in specializationIds)
            {
                var existing = client.PreferredSpecializations.SingleOrDefault(x => x.TherapistSpecializationId == id);
                if (existing != null) existing.IsDeleted = false;
                else client.PreferredSpecializations.Add(new ClientSpecialization { TherapistSpecializationId = id });
            }
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

        if (containsSensitiveAssessmentData &&
     !alreadyAcceptedCurrentConsent)
        {
            _context.UserConsents.Add(
                new UserConsent
                {
                    UserId =
                        userId,

                    ConsentType =
                        UserConsentType
                            .SensitiveDataProcessing,

                    DocumentVersion =
                        ConsentDocumentConstants
                            .SensitiveDataProcessingVersion,

                    IsAccepted =
                        true,

                    AcceptedAtUtc =
                        DateTime.UtcNow
                });
        }

        await _context.SaveChangesAsync(
            cancellationToken);

        return await GetAsync(
            userId,
            cancellationToken);
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

    private static string? SerializeTextValues(IEnumerable<string>? values)
        => ClientPreferenceFormat.SerializeTextValues(values);

    private static List<string> SplitTextValues(string? value)
        => ClientPreferenceFormat.SplitTextValues(value);

    private static string? SerializeDays(IEnumerable<DayOfWeek>? days)
        => ClientPreferenceFormat.SerializeDays(days);

    private static List<DayOfWeek> SplitDays(string? value)
        => ClientPreferenceFormat.SplitDays(value);
}
