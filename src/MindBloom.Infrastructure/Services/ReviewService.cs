using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class ReviewService : IReviewService
{
    private readonly ApplicationDbContext _context;

    public ReviewService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task CreateAsync(
        int clientUserId,
        CreateReviewDto request)
    {
        if (request.Rating < 1 || request.Rating > 5)
        {
            throw new Exception(
                "Rating must be between 1 and 5.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(
                    x => x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception("Client not found.");
        }

        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(
                    x => x.Id == request.TherapistId);

        if (therapist == null)
        {
            throw new Exception("Therapist not found.");
        }

        var hasCompletedAppointment =
            await _context.Appointments
                .AnyAsync(x =>
                    x.ClientId == client.Id
                    && x.TherapistId == request.TherapistId
                    && x.Status == AppointmentStatus.Completed);

        if (!hasCompletedAppointment)
        {
            throw new Exception(
                "You can review only therapists you had completed appointments with.");
        }

        var existingReview =
    await _context.Reviews.AnyAsync(x =>
        x.ClientId == client.Id
        && x.TherapistId == request.TherapistId);

        if (existingReview)
        {
            throw new Exception(
                "You already reviewed this therapist.");
        }

        var review = new Review
        {
            ClientId = client.Id,

            TherapistId = request.TherapistId,

            Rating = request.Rating,

            Comment = request.Comment
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
            .Where(x => x.TherapistId == therapistId)
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

                CreatedAtUtc = x.CreatedAtUtc
            })
            .ToListAsync();
    }

    public async Task<TherapistRatingDto>
        GetTherapistRatingAsync(
            int therapistId)
    {
        var reviews =
            await _context.Reviews
                .Where(x => x.TherapistId == therapistId)
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
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var review =
            await _context.Reviews
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId
                    && x.ClientId == client.Id);

        if (review == null)
        {
            throw new Exception(
                "Review not found.");
        }

        _context.Reviews.Remove(review);

        await _context.SaveChangesAsync();
    }
}