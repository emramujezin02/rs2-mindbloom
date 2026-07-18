using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Application.Recommendations.Services;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Recommendations;

public sealed class RecommendationService : IRecommendationService
{
    private const decimal SpecializationMaximumScore = 25m;
    private const decimal AssessmentMaximumScore = 15m;
    private const decimal PreferenceMaximumScore = 15m;
    private const decimal PriceMaximumScore = 10m;
    private const decimal ExperienceMaximumScore = 10m;
    private const decimal RatingMaximumScore = 10m;
    private const decimal AvailabilityMaximumScore = 10m;
    private const decimal PreviousAppointmentMaximumScore = 3m;
    private const decimal FavoriteMaximumScore = 2m;

    private const int DefaultRecommendationCount = 10;
    private const int MaximumRecommendationCount = 50;

    private static readonly HashSet<string> ApprovedVerificationStatuses =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "Approved",
            "Verified"
        };

    private readonly ApplicationDbContext _context;

    public RecommendationService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<TherapistRecommendationDto>>
        GetRecommendationsAsync(
            int userId,
            TherapistRecommendationRequestDto request,
            CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var client = await _context.Clients
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.UserId == userId &&
                     !x.IsDeleted,
                cancellationToken);

        if (client is null)
        {
            throw new KeyNotFoundException(
                "Client profile was not found for the authenticated user.");
        }

        var preferredSpecializationIds = request
            .PreferredSpecializationIds
            .Where(x => x > 0)
            .ToHashSet();

        var preferredDays = request
            .PreferredDays
            .Distinct()
            .ToHashSet();

        var assessmentFocusAreas = request
            .AssessmentFocusAreas
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(NormalizeText)
            .Where(x => x.Length > 0)
            .Distinct()
            .ToList();

        var previousTherapistIds = await _context.Appointments
            .AsNoTracking()
            .Where(x =>
                x.ClientId == client.Id &&
                !x.IsDeleted)
            .Select(x => x.TherapistId)
            .Distinct()
            .ToHashSetAsync(cancellationToken);

        var favoriteTherapistIds = await _context.Favorites
            .AsNoTracking()
            .Where(x =>
                x.ClientId == client.Id &&
                !x.IsDeleted)
            .Select(x => x.TherapistId)
            .Distinct()
            .ToHashSetAsync(cancellationToken);

        var therapists = await _context.Therapists
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                x.User.IsActive &&
                !x.User.IsBlocked)
            .Include(x => x.User)
            .Include(x => x.SpecializationReference)
            .Include(x => x.Availabilities)
            .Include(x => x.Reviews)
            .ToListAsync(cancellationToken);

        var requestedTake = request.Take <= 0
            ? DefaultRecommendationCount
            : Math.Min(
                request.Take,
                MaximumRecommendationCount);

        var recommendations = therapists
            .Where(IsApprovedTherapist)
            .Select(therapist =>
                CreateRecommendation(
                    therapist,
                    preferredSpecializationIds,
                    assessmentFocusAreas,
                    preferredDays,
                    request.MaximumPricePerSession,
                    request.MinimumExperienceYears,
                    previousTherapistIds.Contains(therapist.Id),
                    favoriteTherapistIds.Contains(therapist.Id)))
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x => x.AverageRating)
            .ThenByDescending(x => x.ExperienceYears)
            .ThenBy(x => x.PricePerSession)
            .Take(requestedTake)
            .ToList();

        return recommendations;
    }

    private static TherapistRecommendationDto CreateRecommendation(
        Therapist therapist,
        IReadOnlySet<int> preferredSpecializationIds,
        IReadOnlyCollection<string> assessmentFocusAreas,
        IReadOnlySet<DayOfWeek> preferredDays,
        decimal? maximumPricePerSession,
        int? minimumExperienceYears,
        bool hasPreviousAppointment,
        bool isFavorite)
    {
        var reasons = new List<RecommendationReasonDto>();

        var specializationScore = CalculateSpecializationScore(
            therapist,
            preferredSpecializationIds,
            reasons);

        var assessmentScore = CalculateAssessmentScore(
            therapist,
            assessmentFocusAreas,
            reasons);

        var preferenceScore = CalculatePreferredDaysScore(
            therapist,
            preferredDays,
            reasons);

        var priceScore = CalculatePriceScore(
            therapist,
            maximumPricePerSession,
            reasons);

        var experienceScore = CalculateExperienceScore(
            therapist,
            minimumExperienceYears,
            reasons);

        var validReviews = therapist.Reviews
            .Where(x =>
                !x.IsDeleted &&
                x.Rating >= 1 &&
                x.Rating <= 5)
            .ToList();

        var averageRating = validReviews.Count == 0
            ? 0m
            : validReviews.Average(x => (decimal)x.Rating);

        var ratingScore = CalculateRatingScore(
            averageRating,
            validReviews.Count,
            reasons);

        var availabilityScore = CalculateAvailabilityScore(
            therapist,
            reasons);

        var previousAppointmentScore =
            CalculatePreviousAppointmentScore(
                hasPreviousAppointment,
                reasons);

        var favoriteScore = CalculateFavoriteScore(
            isFavorite,
            reasons);

        var totalScore =
            specializationScore +
            assessmentScore +
            preferenceScore +
            priceScore +
            experienceScore +
            ratingScore +
            availabilityScore +
            previousAppointmentScore +
            favoriteScore;

        totalScore = Math.Clamp(
            totalScore,
            0m,
            100m);

        var availableDays = therapist.Availabilities
            .Where(x => !x.IsDeleted)
            .Select(x => x.DayOfWeek)
            .Distinct()
            .OrderBy(x => x)
            .ToList();

        var profileImage =
            therapist.ProfileImagePath ??
            therapist.User.ProfileImageUrl;

        var specializationName =
            therapist.SpecializationReference?.Name ??
            therapist.Specialization;

        return new TherapistRecommendationDto
        {
            TherapistId = therapist.Id,
            UserId = therapist.UserId,

            FullName =
                $"{therapist.User.FirstName} {therapist.User.LastName}"
                    .Trim(),

            Specialization = specializationName,

            PricePerSession =
                therapist.PricePerSession > 0
                    ? therapist.PricePerSession
                    : therapist.HourlyRate,

            ExperienceYears = therapist.ExperienceYears,

            ProfileImageUrl = profileImage,

            AverageRating = Math.Round(
                averageRating,
                2),

            ReviewCount = validReviews.Count,

            IsFavorite = isFavorite,

            HasPreviousAppointment =
                hasPreviousAppointment,

            AvailableDays = availableDays,

            Score = Math.Round(
                totalScore,
                2),

            MatchPercentage = (int)Math.Round(
                totalScore,
                MidpointRounding.AwayFromZero),

            Reasons = reasons
                .OrderByDescending(x => x.AwardedPoints)
                .ToList()
        };
    }

    private static decimal CalculateSpecializationScore(
        Therapist therapist,
        IReadOnlySet<int> preferredSpecializationIds,
        ICollection<RecommendationReasonDto> reasons)
    {
        if (preferredSpecializationIds.Count == 0)
        {
            const decimal neutralScore = 10m;

            AddReason(
                reasons,
                "Specialization",
                neutralScore,
                SpecializationMaximumScore,
                "No specific therapeutic specialization was selected.");

            return neutralScore;
        }

        if (therapist.SpecializationId.HasValue &&
            preferredSpecializationIds.Contains(
                therapist.SpecializationId.Value))
        {
            AddReason(
                reasons,
                "Specialization",
                SpecializationMaximumScore,
                SpecializationMaximumScore,
                "The therapist's specialization matches your selected therapeutic approach.");

            return SpecializationMaximumScore;
        }

        AddReason(
            reasons,
            "Specialization",
            0m,
            SpecializationMaximumScore,
            "The therapist's specialization does not directly match the selected approach.");

        return 0m;
    }

    private static decimal CalculateAssessmentScore(
        Therapist therapist,
        IReadOnlyCollection<string> assessmentFocusAreas,
        ICollection<RecommendationReasonDto> reasons)
    {
        if (assessmentFocusAreas.Count == 0)
        {
            const decimal neutralScore = 7.5m;

            AddReason(
                reasons,
                "Initial assessment",
                neutralScore,
                AssessmentMaximumScore,
                "Initial-assessment focus areas were not supplied.");

            return neutralScore;
        }

        var therapistText = NormalizeText(
            string.Join(
                " ",
                therapist.Specialization,
                therapist.SpecializationReference?.Name,
                therapist.SpecializationReference?.Description,
                therapist.Biography));

        var matchedAreas = assessmentFocusAreas
            .Where(therapistText.Contains)
            .Distinct()
            .ToList();

        if (matchedAreas.Count == 0)
        {
            AddReason(
                reasons,
                "Initial assessment",
                0m,
                AssessmentMaximumScore,
                "No direct match was found between the assessment focus areas and the therapist's profile.");

            return 0m;
        }

        var matchRatio =
            Math.Min(
                1m,
                (decimal)matchedAreas.Count /
                assessmentFocusAreas.Count);

        var score =
            AssessmentMaximumScore *
            matchRatio;

        AddReason(
            reasons,
            "Initial assessment",
            score,
            AssessmentMaximumScore,
            $"The therapist's profile matches these assessment areas: {string.Join(", ", matchedAreas)}.");

        return score;
    }

    private static decimal CalculatePreferredDaysScore(
        Therapist therapist,
        IReadOnlySet<DayOfWeek> preferredDays,
        ICollection<RecommendationReasonDto> reasons)
    {
        var therapistDays = therapist.Availabilities
            .Where(x => !x.IsDeleted)
            .Select(x => x.DayOfWeek)
            .Distinct()
            .ToHashSet();

        if (preferredDays.Count == 0)
        {
            var neutralScore = therapistDays.Count > 0
                ? 7.5m
                : 0m;

            AddReason(
                reasons,
                "Preferred schedule",
                neutralScore,
                PreferenceMaximumScore,
                therapistDays.Count > 0
                    ? "The therapist has configured weekly availability."
                    : "The therapist currently has no configured weekly availability.");

            return neutralScore;
        }

        var matchingDays = therapistDays
            .Intersect(preferredDays)
            .ToList();

        var ratio =
            (decimal)matchingDays.Count /
            preferredDays.Count;

        var score =
            PreferenceMaximumScore *
            ratio;

        AddReason(
            reasons,
            "Preferred schedule",
            score,
            PreferenceMaximumScore,
            matchingDays.Count > 0
                ? $"The therapist is available on preferred days: {string.Join(", ", matchingDays)}."
                : "The therapist is not currently available on the selected preferred days.");

        return score;
    }

    private static decimal CalculatePriceScore(
        Therapist therapist,
        decimal? maximumPricePerSession,
        ICollection<RecommendationReasonDto> reasons)
    {
        var price =
            therapist.PricePerSession > 0
                ? therapist.PricePerSession
                : therapist.HourlyRate;

        if (!maximumPricePerSession.HasValue ||
            maximumPricePerSession.Value <= 0)
        {
            const decimal neutralScore = 5m;

            AddReason(
                reasons,
                "Price",
                neutralScore,
                PriceMaximumScore,
                "A maximum session price was not specified.");

            return neutralScore;
        }

        var maximumPrice =
            maximumPricePerSession.Value;

        if (price <= maximumPrice)
        {
            AddReason(
                reasons,
                "Price",
                PriceMaximumScore,
                PriceMaximumScore,
                "The session price is within your selected budget.");

            return PriceMaximumScore;
        }

        var differenceRatio =
            (price - maximumPrice) /
            maximumPrice;

        var score =
            PriceMaximumScore *
            Math.Max(
                0m,
                1m - differenceRatio);

        AddReason(
            reasons,
            "Price",
            score,
            PriceMaximumScore,
            score > 0
                ? "The price is slightly above your selected budget."
                : "The price is significantly above your selected budget.");

        return score;
    }

    private static decimal CalculateExperienceScore(
        Therapist therapist,
        int? minimumExperienceYears,
        ICollection<RecommendationReasonDto> reasons)
    {
        if (minimumExperienceYears.HasValue &&
            minimumExperienceYears.Value > 0)
        {
            var minimumExperience =
                minimumExperienceYears.Value;

            if (therapist.ExperienceYears >= minimumExperience)
            {
                AddReason(
                    reasons,
                    "Experience",
                    ExperienceMaximumScore,
                    ExperienceMaximumScore,
                    $"The therapist has {therapist.ExperienceYears} years of experience and meets your preference.");

                return ExperienceMaximumScore;
            }

            var ratio =
                (decimal)therapist.ExperienceYears /
                minimumExperience;

            var score =
                ExperienceMaximumScore *
                Math.Clamp(
                    ratio,
                    0m,
                    1m);

            AddReason(
                reasons,
                "Experience",
                score,
                ExperienceMaximumScore,
                $"The therapist has {therapist.ExperienceYears} years of experience.");

            return score;
        }

        var generalScore =
            ExperienceMaximumScore *
            Math.Min(
                1m,
                therapist.ExperienceYears / 10m);

        AddReason(
            reasons,
            "Experience",
            generalScore,
            ExperienceMaximumScore,
            $"The therapist has {therapist.ExperienceYears} years of professional experience.");

        return generalScore;
    }

    private static decimal CalculateRatingScore(
        decimal averageRating,
        int reviewCount,
        ICollection<RecommendationReasonDto> reasons)
    {
        if (reviewCount == 0)
        {
            AddReason(
                reasons,
                "Rating",
                0m,
                RatingMaximumScore,
                "The therapist does not have any ratings yet.");

            return 0m;
        }

        var score =
            RatingMaximumScore *
            Math.Clamp(
                averageRating / 5m,
                0m,
                1m);

        AddReason(
            reasons,
            "Rating",
            score,
            RatingMaximumScore,
            $"The therapist has an average rating of {averageRating:0.00} based on {reviewCount} review(s).");

        return score;
    }

    private static decimal CalculateAvailabilityScore(
        Therapist therapist,
        ICollection<RecommendationReasonDto> reasons)
    {
        var availableDayCount = therapist.Availabilities
            .Where(x => !x.IsDeleted)
            .Select(x => x.DayOfWeek)
            .Distinct()
            .Count();

        var score =
            AvailabilityMaximumScore *
            Math.Clamp(
                availableDayCount / 7m,
                0m,
                1m);

        AddReason(
            reasons,
            "Availability",
            score,
            AvailabilityMaximumScore,
            availableDayCount > 0
                ? $"The therapist is available on {availableDayCount} day(s) per week."
                : "The therapist currently has no configured availability.");

        return score;
    }

    private static decimal CalculatePreviousAppointmentScore(
        bool hasPreviousAppointment,
        ICollection<RecommendationReasonDto> reasons)
    {
        var score = hasPreviousAppointment
            ? PreviousAppointmentMaximumScore
            : 0m;

        AddReason(
            reasons,
            "Previous appointments",
            score,
            PreviousAppointmentMaximumScore,
            hasPreviousAppointment
                ? "You have previously booked an appointment with this therapist."
                : "You have not previously booked an appointment with this therapist.");

        return score;
    }

    private static decimal CalculateFavoriteScore(
        bool isFavorite,
        ICollection<RecommendationReasonDto> reasons)
    {
        var score = isFavorite
            ? FavoriteMaximumScore
            : 0m;

        AddReason(
            reasons,
            "Favorite therapist",
            score,
            FavoriteMaximumScore,
            isFavorite
                ? "You previously added this therapist to your favorites."
                : "This therapist is not currently in your favorites.");

        return score;
    }

    private static bool IsApprovedTherapist(
        Therapist therapist)
    {
        return ApprovedVerificationStatuses.Contains(
            therapist.VerificationStatus.ToString());
    }

    private static string NormalizeText(
        string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        return value
            .Trim()
            .ToLowerInvariant();
    }

    private static void AddReason(
        ICollection<RecommendationReasonDto> reasons,
        string criterion,
        decimal awardedPoints,
        decimal maximumPoints,
        string explanation)
    {
        reasons.Add(
            new RecommendationReasonDto
            {
                Criterion = criterion,

                AwardedPoints = Math.Round(
                    awardedPoints,
                    2),

                MaximumPoints = maximumPoints,

                Explanation = explanation
            });
    }
}