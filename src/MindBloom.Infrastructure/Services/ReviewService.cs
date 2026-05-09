using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class ReviewService : IReviewService
{
    private readonly ApplicationDbContext _context;

    public ReviewService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task CreateAsync(
        int clientUserId,
        CreateReviewDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(
                    x => x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception("Client not found.");
        }

        var therapistExists =
            await _context.Therapists
                .AnyAsync(x => x.Id == request.TherapistId);

        if (!therapistExists)
        {
            throw new Exception("Therapist not found.");
        }

        if (request.Rating < 1 || request.Rating > 5)
        {
            throw new Exception(
                "Rating must be between 1 and 5.");
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
        GetTherapistReviewsAsync(int therapistId)
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
}