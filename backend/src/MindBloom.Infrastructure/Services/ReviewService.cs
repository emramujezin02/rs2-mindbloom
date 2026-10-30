using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Queries;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;

namespace MindBloom.Infrastructure.Services;

public class ReviewService : IReviewService
{
    private readonly ApplicationDbContext _context;
    private readonly TimeProvider _timeProvider;

    private readonly IBusinessNotificationService _businessNotificationService;

    public ReviewService(
    ApplicationDbContext context,
    IBusinessNotificationService
        businessNotificationService, TimeProvider? timeProvider = null)
    {
        _context = context;
        _timeProvider = timeProvider ?? TimeProvider.System;

        _businessNotificationService = businessNotificationService;
    }

    public async Task CreateAsync(
     int clientUserId,
     CreateReviewDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        BusinessRuleGuard.AgainstNotOwned(
            appointment.ClientId == client.Id,
            "You can review only your own appointment.");

        BusinessRuleGuard.Against(
            appointment.Status !=
            AppointmentStatus.Completed,
            "A review can only be submitted after the appointment is completed.");

        var existingReview =
            await _context.Reviews
                .AnyAsync(x =>
                    x.AppointmentId ==
                        appointment.Id &&
                    !x.IsDeleted);

        BusinessRuleGuard.Against(
            existingReview,
            "A review has already been submitted for this appointment.");

        var review = new Review
        {
            ShareAuthorDemographics = request.ShareAuthorDemographics,
            ClientId =
                client.Id,

            TherapistId =
                appointment.TherapistId,

            AppointmentId =
                appointment.Id,

            Rating =
                request.Rating,

            Comment =
                request.Comment.Trim(),

            IsApproved =
                false,

            ModerationStatus =
                ReviewModerationStatus.Pending
        };

        _context.Reviews.Add(review);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException exception)
        {
            throw new BusinessException(
                "A review has already been submitted for this appointment.",
                exception);
        }
    }

    public async Task<List<PublicReviewDto>>
    GetPublicReviewsAsync(
        int limit)
    {
        const int defaultLimit = 6;

        const int maximumLimit = 10;

        var normalizedLimit =
            limit < 1
                ? defaultLimit
                : Math.Min(
                    limit,
                    maximumLimit);

        var visibleTherapistIds = _context.Therapists
            .Where(TherapistVisibility.PubliclyVisible).Select(x => x.Id);

        var reviews =
            await _context.Reviews
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
.Where(x =>
    x.IsApproved &&
    !x.IsDeleted &&
    x.ModerationStatus ==
        ReviewModerationStatus.Approved &&
    !x.Client.IsDeleted &&
    visibleTherapistIds.Contains(x.TherapistId) &&
    !x.Client.User.IsBlocked &&
    x.Client.User.IsActive)
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Take(normalizedLimit)
                .Select(x =>
                    new
                    {
                        x.Id,

                        ClientFirstName =
                            x.Client.User.FirstName,

                        ClientLastName =
                            x.Client.User.LastName,
                        x.Client.User.Gender,
                        x.Client.User.DateOfBirth,
                        CanShareDemographics = x.ShareAuthorDemographics && x.Client.User.Settings != null && x.Client.User.Settings.ShowProfilePublicly,

                        x.Rating,

                        x.Comment,

                        x.TherapistId,

                        TherapistFirstName =
                            x.Therapist.User.FirstName,

                        TherapistLastName =
                            x.Therapist.User.LastName,

                        x.CreatedAtUtc
                    })
                .ToListAsync();

        var today = _timeProvider.GetUtcNow().UtcDateTime.Date;
        return reviews
            .Select(x =>
                new PublicReviewDto
                {
                    AuthorAge = x.CanShareDemographics && PublicReviewDemographics.CalculateAge(x.DateOfBirth, today) is >= 18 ? PublicReviewDemographics.CalculateAge(x.DateOfBirth, today) : null,
                    AuthorGender = x.CanShareDemographics && PublicReviewDemographics.CalculateAge(x.DateOfBirth, today) is >= 18 ? PublicReviewDemographics.NormalizeGender(x.Gender) : null,
                    Id =
                        x.Id,

                    ClientInitials =
                        BuildClientInitials(
                            x.ClientFirstName,
                            x.ClientLastName),

                    Rating =
                        x.Rating,

                    Comment =
                        x.Comment,

                    TherapistId =
                        x.TherapistId,

                    TherapistName =
                        (
                            x.TherapistFirstName
                            + " "
                            + x.TherapistLastName
                        )
                        .Trim(),

                    CreatedAtUtc =
                        x.CreatedAtUtc
                })
            .ToList();
    }


    public async Task<PagedResponse<ReviewResponseDto>>
    GetTherapistReviewsAsync(
        int therapistId,
        ReviewFilterDto filter)
    {
        await EnsurePublicTherapistAsync(therapistId);

        var pagination =
            PaginationHelper.Normalize(
                filter.PageNumber,
                filter.PageSize);

        var query =
            _context.Reviews
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Where(x =>
                    x.TherapistId == therapistId &&
                    x.IsApproved &&
                    !x.IsDeleted &&
                    x.ModerationStatus ==
                        ReviewModerationStatus.Approved);

        query = filter.SortBy switch
        {
            ReviewSortBy.Newest =>
                query.OrderByDescending(x =>
                    x.CreatedAtUtc),

            ReviewSortBy.Oldest =>
                query.OrderBy(x =>
                    x.CreatedAtUtc),

            ReviewSortBy.HighestRating =>
                query.OrderByDescending(x =>
                    x.Rating)
                .ThenByDescending(x =>
                    x.CreatedAtUtc),

            ReviewSortBy.LowestRating =>
                query.OrderBy(x =>
                    x.Rating)
                .ThenByDescending(x =>
                    x.CreatedAtUtc),

            _ =>
                query.OrderByDescending(x =>
                    x.CreatedAtUtc)
        };

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .Skip(
                    pagination.Skip)
                .Take(
                    pagination.PageSize)
                .Select(x =>
                    new ReviewResponseDto
                    {
                        Id =
                            x.Id,

                        ClientName =
    x.Client.User.FirstName
    + " "
    + x.Client.User.LastName
        .Substring(
            0,
            1)
    + ".",

                        Rating =
                            x.Rating,

                        Comment =
                            x.Comment,

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        TherapistReply =
                            x.TherapistReply,

                        TherapistReplyCreatedAtUtc =
                            x.TherapistReplyCreatedAtUtc
                    })
                .ToListAsync();

        return PagedResponse<ReviewResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<TherapistRatingDto>
        GetTherapistRatingAsync(
            int therapistId)
    {
        await EnsurePublicTherapistAsync(therapistId);

        var reviews =
            await _context.Reviews
                .Where(x =>
                    x.TherapistId == therapistId &&
                    x.IsApproved &&
                    !x.IsDeleted &&
                    x.ModerationStatus ==
                        ReviewModerationStatus.Approved)
                .ToListAsync();

        if (!reviews.Any())
        {
            return new TherapistRatingDto
            {
                TherapistId = therapistId,
                AverageRating = 0,
                TotalReviews = 0
            };
        }

        return new TherapistRatingDto
        {
            TherapistId = therapistId,

            AverageRating =
                Math.Round(
                    reviews.Average(x => x.Rating),
                    1),

            TotalReviews = reviews.Count
        };
    }

    private async Task EnsurePublicTherapistAsync(int therapistId)
    {
        if (!await _context.Therapists
                .Where(TherapistVisibility.PubliclyVisible)
                .AnyAsync(x => x.Id == therapistId))
        {
            throw new NotFoundException("Therapist not found or is not publicly available.");
        }
    }

    public async Task<ReviewEligibilityDto>
    GetEligibilityAsync(
        int clientUserId,
        int appointmentId)
    {
        var client =
            await _context.Clients
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        if (appointment.ClientId != client.Id)
        {
            return new ReviewEligibilityDto
            {
                AppointmentId = appointmentId,
                CanReview = false,
                Message =
                    "You can review only your own appointment."
            };
        }

        if (appointment.Status !=
            AppointmentStatus.Completed)
        {
            return new ReviewEligibilityDto
            {
                AppointmentId = appointmentId,
                CanReview = false,
                Message =
                    "A review can only be submitted after the appointment is completed."
            };
        }

        var existingReview =
            await _context.Reviews
                .AsNoTracking()
                .Where(x =>
                    x.AppointmentId == appointmentId &&
                    !x.IsDeleted)
.Select(x => new
{
    x.Id,
    x.ModerationStatus
})
                .FirstOrDefaultAsync();

        if (existingReview != null)
        {
            return new ReviewEligibilityDto
            {
                AppointmentId = appointmentId,
                CanReview = false,
                ExistingReviewId =
                    existingReview.Id,
                ModerationStatus =
    existingReview.ModerationStatus
        .ToString(),
                Message =
                    "A review has already been submitted for this appointment."
            };
        }

        return new ReviewEligibilityDto
        {
            AppointmentId = appointmentId,
            CanReview = true,
            Message =
                "You can submit a review for this appointment."
        };
    }

    public async Task DeleteAsync(
      int clientUserId,
      int reviewId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var review =
            await _context.Reviews
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId &&
                    !x.IsDeleted);

        if (review == null)
        {
            throw new NotFoundException(
                "Review not found.");
        }

        BusinessRuleGuard.AgainstNotOwned(
            review.ClientId == client.Id,
            "You can delete only your own review.");

        review.IsDeleted = true;

        review.IsApproved = false;

        review.ModerationReason =
            "Deleted by the review author.";

        review.ModeratedAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(
     int clientUserId,
     int reviewId,
     UpdateReviewDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var review =
            await _context.Reviews
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId &&
                    !x.IsDeleted);

        if (review == null)
        {
            throw new NotFoundException(
                "Review not found.");
        }

        BusinessRuleGuard.AgainstNotOwned(
            review.ClientId == client.Id,
            "You can update only your own review.");

        if (request.ShareAuthorDemographics.HasValue)
        {
            review.ShareAuthorDemographics = request.ShareAuthorDemographics.Value;
            if (review.Rating == request.Rating && review.Comment == request.Comment.Trim())
            {
                review.UpdatedAtUtc = _timeProvider.GetUtcNow().UtcDateTime;
                await _context.SaveChangesAsync();
                return;
            }
        }

        review.Rating =
            request.Rating;

        review.Comment =
            request.Comment.Trim();

        review.IsApproved =
            false;

        review.IsDeleted =
            false;

        review.ModerationStatus =
            ReviewModerationStatus.Pending;

        review.ModeratedByUserId =
            null;

        review.ModeratedAtUtc =
            null;

        review.ModerationReason =
            null;

        review.UpdatedAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }


    public async Task<PagedResponse<ClientReviewDto>>
     GetMyReviewsAsync(
         int clientUserId,
         int pageNumber,
         int pageSize)
    {
        var pagination =
            PaginationHelper.Normalize(
                pageNumber,
                pageSize);

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var query =
            _context.Reviews
                .AsNoTracking()
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Where(x =>
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    pagination.Skip)
                .Take(
                    pagination.PageSize)
                .Select(x =>
new ClientReviewDto
{
    ShareAuthorDemographics = x.ShareAuthorDemographics,
    Id = x.Id,

    AppointmentId =
        x.AppointmentId,

    TherapistId =
        x.TherapistId,

    TherapistName =
        x.Therapist.User.FirstName
        + " "
        + x.Therapist.User.LastName,

    Rating =
        x.Rating,

    Comment =
        x.Comment,

    CreatedAtUtc =
        x.CreatedAtUtc,

    IsApproved =
        x.IsApproved,

    ModerationStatus =
    x.ModerationStatus
        .ToString(),

    CanEdit =
        true,

    ModerationReason =
        x.ModerationReason,

    TherapistReply =
        x.TherapistReply,

    TherapistReplyCreatedAtUtc =
        x.TherapistReplyCreatedAtUtc
})
                .ToListAsync();

        return PagedResponse<ClientReviewDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task ReplyToReviewAsync(
     int therapistUserId,
     int reviewId,
     ReplyToReviewDto request)
    {
        var reply = request.Reply?.Trim() ?? string.Empty;


        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                        therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException("Therapist not found.");
        }

        var review =
            await _context.Reviews
                .Include(x =>
                    x.Client)
                .ThenInclude(x =>
                    x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        reviewId &&
                    x.TherapistId ==
                        therapist.Id && !x.IsDeleted);

        if (review == null)
        {
            throw new NotFoundException("Review not found.");
        }

        var isSameReply =
            string.Equals(
                review.TherapistReply,
                reply,
                StringComparison.Ordinal);

        if (isSameReply)
        {
            return;
        }

        review.TherapistReply = reply;

        review.TherapistReplyCreatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        await _businessNotificationService
            .PublishAsync(
                review.Client.UserId,
                "Therapist replied to your review",
                "Your therapist has replied to one of your reviews.",
                actionType:
                    NotificationActionType.Review,
                resourceId:
                    review.Id);
    }

    private static string
    BuildClientInitials(
        string? firstName,
        string? lastName)
    {
        var initials =
            new List<string>();

        if (!string.IsNullOrWhiteSpace(
                firstName))
        {
            initials.Add(
                char.ToUpperInvariant(
                    firstName.Trim()[0])
                + ".");
        }

        if (!string.IsNullOrWhiteSpace(
                lastName))
        {
            initials.Add(
                char.ToUpperInvariant(
                    lastName.Trim()[0])
                + ".");
        }

        return initials.Count == 0
            ? "MB"
            : string.Join(
                " ",
                initials);
    }
}
