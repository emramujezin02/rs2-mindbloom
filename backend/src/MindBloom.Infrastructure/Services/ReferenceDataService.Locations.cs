using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Domain.Entities;

namespace MindBloom.Infrastructure.Services;

public partial class ReferenceDataService
{
    private static readonly Expression<Func<TherapistLocation, TherapistLocationResponseDto>> LocationResponse = x => new()
    {
        Id = x.Id, Name = x.Name, Country = x.Country, Region = x.Region, IsActive = x.IsActive,
        TherapistCount = x.Therapists.Count(t => !t.IsDeleted)
    };

    public async Task<PagedResponse<TherapistLocationResponseDto>> GetTherapistLocationsAsync(
        TherapistLocationQueryDto request, CancellationToken cancellationToken = default)
    {
        var page = PaginationHelper.Normalize(request.PageNumber, request.PageSize);
        var query = _context.TherapistLocations.AsNoTracking().Where(x => !x.IsDeleted);
        if (request.IsActive.HasValue) query = query.Where(x => x.IsActive == request.IsActive.Value);
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(x => x.Name.Contains(search) || x.Country.Contains(search) || x.Region.Contains(search));
        }
        var count = await query.CountAsync(cancellationToken);
        var skip = (int)Math.Min((long)(page.PageNumber - 1) * page.PageSize, int.MaxValue);
        var items = await query.OrderBy(x => x.Name).ThenBy(x => x.Country).ThenBy(x => x.Region).ThenBy(x => x.Id)
            .Skip(skip).Take(page.PageSize).Select(LocationResponse).ToListAsync(cancellationToken);
        return PagedResponse<TherapistLocationResponseDto>.Create(items, page.PageNumber, page.PageSize, count);
    }

    public async Task<TherapistLocationResponseDto> GetTherapistLocationByIdAsync(int id, CancellationToken cancellationToken = default)
        => await _context.TherapistLocations.AsNoTracking().Where(x => x.Id == id && !x.IsDeleted)
            .Select(LocationResponse).SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("Location not found.");

    public async Task<TherapistLocationResponseDto> SaveTherapistLocationAsync(int? id, SaveTherapistLocationDto request,
        CancellationToken cancellationToken = default)
    {
        var name = request.Name?.Trim() ?? "";
        var country = request.Country?.Trim() ?? "";
        var region = request.Region?.Trim() ?? "";
        if (name.Length is < 1 or > 100 || country.Length is < 1 or > 100 || region.Length > 100)
            throw new BadRequestException("Location name and country are required (maximum 100 characters); region may contain up to 100 characters.");
        if (await _context.TherapistLocations.AnyAsync(x => x.Id != id && !x.IsDeleted &&
            x.Name.ToLower() == name.ToLower() && x.Country.ToLower() == country.ToLower() && x.Region.ToLower() == region.ToLower(), cancellationToken))
            throw new BusinessException("A location with the same name, country and region already exists.");
        var entity = id.HasValue
            ? await _context.TherapistLocations.SingleOrDefaultAsync(x => x.Id == id && !x.IsDeleted, cancellationToken)
                ?? throw new NotFoundException("Location not found.")
            : new TherapistLocation();
        entity.Name = name;
        entity.Country = country;
        entity.Region = region;
        entity.IsActive = request.IsActive;
        if (!id.HasValue) _context.TherapistLocations.Add(entity);
        else
        {
            entity.UpdatedAtUtc = DateTime.UtcNow;
            // Keep the legacy display fields consistent without changing addresses.
            var therapists = await _context.Therapists.Where(x => x.LocationId == id).ToListAsync(cancellationToken);
            foreach (var therapist in therapists)
            {
                therapist.City = name;
                therapist.Country = country;
                therapist.Location = name;
            }
        }
        try { await _context.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateException exception) when (exception.InnerException is Microsoft.Data.SqlClient.SqlException sql && sql.Number is 2601 or 2627)
        {
            throw new BusinessException("A location with the same name, country and region already exists.", exception);
        }
        return await GetTherapistLocationByIdAsync(entity.Id, cancellationToken);
    }

    public async Task DeleteTherapistLocationAsync(int id, CancellationToken cancellationToken = default)
    {
        var entity = await _context.TherapistLocations.SingleOrDefaultAsync(x => x.Id == id && !x.IsDeleted, cancellationToken)
            ?? throw new NotFoundException("Location not found.");
        // Referenced locations remain available to existing profiles; only new selection is disabled.
        if (await _context.Therapists.AnyAsync(x => x.LocationId == id, cancellationToken)) entity.IsActive = false;
        else { entity.IsDeleted = true; entity.IsActive = false; }
        entity.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
    }
}
