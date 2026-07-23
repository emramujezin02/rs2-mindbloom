using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;

namespace MindBloom.Infrastructure.Services;

public class ReviewService : IReviewService
{
    private readonly ApplicationDbContext _context;

    private readonly IBusinessNotificationService _businessNotificationService;

    public ReviewService(
    ApplicationDbContext context,
    IBusinessNotificationService
        businessNotificationService)
    {
        _context = context;

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
                ClientId = client.Id,
                TherapistId = appointment.TherapistId,
                AppointmentId = appointment.Id,
                Rating = request.Rating,
                Comment = request.Comment.Trim(),
                IsApproved = false
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
                    !x.Client.IsDeleted &&
                    !x.Therapist.IsDeleted &&
                    !x.Client.User.IsBlocked &&
                    x.Client.User.IsActive &&
                    !x.Therapist.User.IsBlocked &&
                    x.Therapist.User.IsActive &&
                    x.Therapist.VerificationStatus ==
                        TherapistVerificationStatus
                            .Approved)
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

        return reviews
            .Select(x =>
                new PublicReviewDto
                {
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
    !x.IsDeleted);

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
        var reviews =
            await _context.Reviews
                .Where(x => x.TherapistId == therapistId && !x.IsDeleted)
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

        review.Rating =
            request.Rating;

        review.Comment =
            request.Comment.Trim();

        review.IsApproved =
    false;

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
                        Id =
                            x.Id,

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
                review.AppointmentId);
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