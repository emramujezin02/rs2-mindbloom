using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Exceptions;

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
        if (request.Rating < 1 ||
            request.Rating > 5)
        {
            throw new Exception(
                "Rating must be between 1 and 5.");
        }

        var comment =
            request.Comment.Trim();

        if (string.IsNullOrWhiteSpace(comment))
        {
            throw new Exception(
                "Review comment is required.");
        }

        if (comment.Length > 1000)
        {
            throw new Exception(
                "Review comment may contain at most 1000 characters.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId &&
                    x.ClientId == client.Id);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found or does not belong to the current client.");
        }

        if (appointment.Status !=
            AppointmentStatus.Completed)
        {
            throw new Exception(
                "A review can only be submitted after the appointment is completed.");
        }

        var existingReview =
            await _context.Reviews
                .AnyAsync(x =>
                    x.AppointmentId ==
                    appointment.Id);

        if (existingReview)
        {
            throw new BusinessException(
                "A review has already been submitted for this appointment.");
        }

        var review = new Review
        {
            ClientId = client.Id,
            TherapistId =
                appointment.TherapistId,
            AppointmentId =
                appointment.Id,
            Rating = request.Rating,
            Comment = comment
        };

        _context.Reviews.Add(review);

        await _context.SaveChangesAsync();
    }

    public async Task<List<ReviewResponseDto>>
        GetTherapistReviewsAsync(
            int therapistId)
    {
        return await _context.Reviews
            .Include(x => x.Client)
            .ThenInclude(x => x.User)
            .Where(x => x.TherapistId == therapistId && !x.IsDeleted)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new ReviewResponseDto
            {
                Id = x.Id,

                ClientName =
                    x.Client.User.FirstName
                    + " "
                    + x.Client.User.LastName,

                Rating = x.Rating,

                Comment = x.Comment,

                CreatedAtUtc = x.CreatedAtUtc,

                TherapistReply = x.TherapistReply,
                TherapistReplyCreatedAtUtc = x.TherapistReplyCreatedAtUtc,
            })
            .ToListAsync();
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
                    x.UserId ==
                    clientUserId);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var review =
            await _context.Reviews
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId
                    && x.ClientId ==
                        client.Id
                    && !x.IsDeleted);

        if (review == null)
        {
            throw new NotFoundException(
                "Review not found.");
        }

        review.IsDeleted =
            true;

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
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new NotFoundException("Client not found.");
        }

        var review =
    await _context.Reviews
        .FirstOrDefaultAsync(x =>
            x.Id == reviewId
            && x.ClientId == client.Id
            && !x.IsDeleted);

        if (review == null)
        {
            throw new NotFoundException(
                "Review not found.");
        }

        review.Rating = request.Rating;

        review.Comment = request.Comment;

        await _context.SaveChangesAsync();
    }

    public async Task<List<ClientReviewDto>>
    GetMyReviewsAsync(
        int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        return await _context.Reviews
            .Include(x => x.Therapist)
                .ThenInclude(x => x.User)
            .Where(x =>
                x.ClientId == client.Id && !x.IsDeleted)
            .OrderByDescending(x =>
                x.CreatedAtUtc)
            .Select(x => new ClientReviewDto
            {
                Id = x.Id,

                TherapistId =
                    x.TherapistId,

                TherapistName =
                    x.Therapist.User.FirstName
                    + " "
                    + x.Therapist.User.LastName,

                Rating = x.Rating,

                Comment = x.Comment,

                CreatedAtUtc =
                    x.CreatedAtUtc,

                TherapistReply = x.TherapistReply,
                TherapistReplyCreatedAtUtc = x.TherapistReplyCreatedAtUtc,
            })
            .ToListAsync();
    }

    public async Task ReplyToReviewAsync(
     int therapistUserId,
     int reviewId,
     ReplyToReviewDto request)
    {
        var reply = request.Reply?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(reply))
        {
            throw new Exception("Review reply is required.");
        }

        if (reply.Length > 1000)
        {
            throw new Exception("Review reply may contain at most 1000 characters.");
        }

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

    public async Task<List<ReviewResponseDto>>
    GetTherapistReviewsAsync(
        int therapistId,
        ReviewFilterDto filter)
    {
        var query =
            _context.Reviews
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Where(x =>
                    x.TherapistId == therapistId && !x.IsDeleted);

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
                    x.Rating),

            ReviewSortBy.LowestRating =>
                query.OrderBy(x =>
                    x.Rating),

            _ =>
                query.OrderByDescending(x =>
                    x.CreatedAtUtc)
        };

        return await query
            .Select(x => new ReviewResponseDto
            {
                Id = x.Id,

                ClientName =
                    x.Client.User.FirstName
                    + " "
                    + x.Client.User.LastName,

                Rating = x.Rating,

                Comment = x.Comment,

                CreatedAtUtc =
                    x.CreatedAtUtc,

                TherapistReply =
                    x.TherapistReply,

                TherapistReplyCreatedAtUtc =
                    x.TherapistReplyCreatedAtUtc
            })
            .ToListAsync();
    }
}