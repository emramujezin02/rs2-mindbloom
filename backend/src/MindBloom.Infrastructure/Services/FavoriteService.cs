using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Favorites.DTOs;
using MindBloom.Application.Features.Favorites.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;

using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;

namespace MindBloom.Infrastructure.Services;

public class FavoriteService : IFavoriteService
{
    private readonly ApplicationDbContext _context;

    public FavoriteService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        int clientUserId,
        AddFavoriteDto request)
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

        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.Id == request.TherapistId);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var existingFavorite =
            await _context.Favorites
                .AnyAsync(x =>
                    x.ClientId == client.Id
                    && x.TherapistId ==
                        request.TherapistId);

        if (existingFavorite)
        {
            throw new BusinessException(
                "Therapist is already in favorites.");
        }

        var favorite = new Favorite
        {
            ClientId = client.Id,
            TherapistId = request.TherapistId
        };

        _context.Favorites.Add(favorite);

        await _context.SaveChangesAsync();
    }

    public async Task RemoveAsync(
        int clientUserId,
        int therapistId)
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

        var favorite =
            await _context.Favorites
                .FirstOrDefaultAsync(x =>
                    x.ClientId == client.Id
                    && x.TherapistId == therapistId);

        if (favorite == null)
        {
            throw new NotFoundException(
                "Favorite not found.");
        }

        _context.Favorites.Remove(favorite);

        await _context.SaveChangesAsync();
    }

    public async Task<PagedResponse<FavoriteResponseDto>>
        GetMyFavoritesAsync(
            int clientUserId,
            int pageNumber,
            int pageSize,
            int? therapistId)
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

        var pagination =
            PaginationHelper.Normalize(
                pageNumber,
                pageSize);

        var query =
            _context.Favorites
            .Include(x => x.Therapist)
            .ThenInclude(x => x.User)
            .Where(x =>
                x.ClientId == client.Id &&
                (!therapistId.HasValue ||
                    x.TherapistId == therapistId.Value))
            .OrderBy(x => x.Therapist.User.FirstName)
            .ThenBy(x => x.Therapist.User.LastName)
            .ThenBy(x => x.TherapistId);

        var totalCount =
            await query.CountAsync();

        var favorites =
            await query
            .Skip(pagination.Skip)
            .Take(pagination.PageSize)
            .Select(x => new FavoriteResponseDto
            {
                TherapistId =
                    x.TherapistId,

                TherapistName =
                    x.Therapist.User.FirstName
                    + " "
                    + x.Therapist.User.LastName,

                Specialization =
                    x.Therapist.Specialization
            })
            .ToListAsync();

        return PagedResponse<FavoriteResponseDto>
            .Create(
                favorites,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }
}
