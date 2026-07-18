using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Application.Features.ReferenceData.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class ReferenceDataService : IReferenceDataService
{
    private readonly ApplicationDbContext _context;

    public ReferenceDataService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<TherapistSpecializationResponseDto>>
        GetActiveTherapistSpecializationsAsync(
            CancellationToken cancellationToken = default)
    {
        return await _context.TherapistSpecializations
            .AsNoTracking()
            .Where(x => !x.IsDeleted && x.IsActive)
            .OrderBy(x => x.Name)
            .Select(x => new TherapistSpecializationResponseDto
            {
                Id = x.Id,
                Name = x.Name,
                Description = x.Description,
                IsActive = x.IsActive,
                TherapistCount = x.Therapists.Count(t => !t.IsDeleted),
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc
            })
            .ToListAsync(cancellationToken);
    }

    public async Task<TherapistSpecializationPagedResponseDto>
        GetTherapistSpecializationsAsync(
            TherapistSpecializationQueryDto query,
            CancellationToken cancellationToken = default)
    {
        var pageNumber = query.PageNumber < 1
            ? 1
            : query.PageNumber;

        var pageSize = query.PageSize switch
        {
            < 1 => 10,
            > 100 => 100,
            _ => query.PageSize
        };

        var specializations = _context.TherapistSpecializations
            .AsNoTracking()
            .Where(x => !x.IsDeleted);

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var normalizedSearch = query.Search.Trim();

            specializations = specializations.Where(x =>
                x.Name.Contains(normalizedSearch) ||
                (x.Description != null &&
                 x.Description.Contains(normalizedSearch)));
        }

        if (query.IsActive.HasValue)
        {
            specializations = specializations.Where(x =>
                x.IsActive == query.IsActive.Value);
        }

        var totalCount = await specializations.CountAsync(
            cancellationToken);

        var items = await specializations
            .OrderBy(x => x.Name)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new TherapistSpecializationResponseDto
            {
                Id = x.Id,
                Name = x.Name,
                Description = x.Description,
                IsActive = x.IsActive,
                TherapistCount = x.Therapists.Count(t => !t.IsDeleted),
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc
            })
            .ToListAsync(cancellationToken);

        return new TherapistSpecializationPagedResponseDto
        {
            Items = items,
            PageNumber = pageNumber,
            PageSize = pageSize,
            TotalCount = totalCount,
            TotalPages = totalCount == 0
                ? 0
                : (int)Math.Ceiling(totalCount / (double)pageSize)
        };
    }

    public async Task<TherapistSpecializationResponseDto>
        GetTherapistSpecializationByIdAsync(
            int id,
            CancellationToken cancellationToken = default)
    {
        var specialization = await FindSpecializationAsync(
            id,
            cancellationToken);

        var therapistCount = await _context.Therapists
            .CountAsync(
                x => !x.IsDeleted &&
                     x.SpecializationId == specialization.Id,
                cancellationToken);

        return MapResponse(
            specialization,
            therapistCount);
    }

    public async Task<TherapistSpecializationResponseDto>
        CreateTherapistSpecializationAsync(
            CreateTherapistSpecializationDto request,
            CancellationToken cancellationToken = default)
    {
        var name = NormalizeName(request.Name);

        ValidateName(name);

        var exists = await _context.TherapistSpecializations
            .AnyAsync(
                x => !x.IsDeleted &&
                     x.Name.ToLower() == name.ToLower(),
                cancellationToken);

        if (exists)
        {
            throw new BusinessException(
                "A therapist specialization with the same name already exists.");
        }

        var specialization = new TherapistSpecialization
        {
            Name = name,
            Description = NormalizeDescription(request.Description),
            IsActive = request.IsActive
        };

        _context.TherapistSpecializations.Add(
            specialization);

        await _context.SaveChangesAsync(
            cancellationToken);

        return MapResponse(
            specialization,
            0);
    }

    public async Task<TherapistSpecializationResponseDto>
        UpdateTherapistSpecializationAsync(
            int id,
            UpdateTherapistSpecializationDto request,
            CancellationToken cancellationToken = default)
    {
        var specialization = await FindSpecializationAsync(
            id,
            cancellationToken);

        var name = NormalizeName(request.Name);

        ValidateName(name);

        var duplicateExists = await _context.TherapistSpecializations
            .AnyAsync(
                x => x.Id != id &&
                     !x.IsDeleted &&
                     x.Name.ToLower() == name.ToLower(),
                cancellationToken);

        if (duplicateExists)
        {
            throw new BusinessException(
                "A therapist specialization with the same name already exists.");
        }

        var oldName = specialization.Name;

        specialization.Name = name;
        specialization.Description =
            NormalizeDescription(request.Description);

        /*
         * Dok postoji legacy string polje, njegov naziv se mora
         * sinhronizovati nakon izmjene referentnog podatka.
         */
        var therapists = await _context.Therapists
            .Where(x =>
                !x.IsDeleted &&
                x.SpecializationId == specialization.Id)
            .ToListAsync(cancellationToken);

        foreach (var therapist in therapists)
        {
            therapist.Specialization = name;
        }

        /*
         * Ovim se obuhvataju i postojeći terapeuti iz perioda
         * prije uvođenja SpecializationId.
         */
        var legacyTherapists = await _context.Therapists
            .Where(x =>
                !x.IsDeleted &&
                x.SpecializationId == null &&
                x.Specialization == oldName)
            .ToListAsync(cancellationToken);

        foreach (var therapist in legacyTherapists)
        {
            therapist.SpecializationId = specialization.Id;
            therapist.Specialization = name;
        }

        await _context.SaveChangesAsync(
            cancellationToken);

        return MapResponse(
            specialization,
            therapists.Count + legacyTherapists.Count);
    }

    public async Task<TherapistSpecializationResponseDto>
        UpdateTherapistSpecializationStatusAsync(
            int id,
            UpdateTherapistSpecializationStatusDto request,
            CancellationToken cancellationToken = default)
    {
        var specialization = await FindSpecializationAsync(
            id,
            cancellationToken);

        specialization.IsActive = request.IsActive;

        await _context.SaveChangesAsync(
            cancellationToken);

        var therapistCount = await _context.Therapists
            .CountAsync(
                x => !x.IsDeleted &&
                     x.SpecializationId == specialization.Id,
                cancellationToken);

        return MapResponse(
            specialization,
            therapistCount);
    }

    public async Task DeleteTherapistSpecializationAsync(
        int id,
        CancellationToken cancellationToken = default)
    {
        var specialization = await FindSpecializationAsync(
            id,
            cancellationToken);

        var isUsed = await _context.Therapists
            .AnyAsync(
                x => !x.IsDeleted &&
                     x.SpecializationId == specialization.Id,
                cancellationToken);

        if (!isUsed)
        {
            isUsed = await _context.Therapists
                .AnyAsync(
                    x => !x.IsDeleted &&
                         x.SpecializationId == null &&
                         x.Specialization == specialization.Name,
                    cancellationToken);
        }

        if (isUsed)
        {
            throw new InvalidOperationException(
                "The specialization cannot be deleted because it is used by one or more therapists. Deactivate it instead.");
        }

        specialization.IsDeleted = true;
        specialization.IsActive = false;

        await _context.SaveChangesAsync(
            cancellationToken);
    }

    private async Task<TherapistSpecialization>
        FindSpecializationAsync(
            int id,
            CancellationToken cancellationToken)
    {
        var specialization = await _context.TherapistSpecializations
            .FirstOrDefaultAsync(
                x => x.Id == id && !x.IsDeleted,
                cancellationToken);

        if (specialization == null)
        {
            throw new NotFoundException(
                "Therapist specialization was not found.");
        }

        return specialization;
    }

    private static TherapistSpecializationResponseDto MapResponse(
        TherapistSpecialization specialization,
        int therapistCount)
    {
        return new TherapistSpecializationResponseDto
        {
            Id = specialization.Id,
            Name = specialization.Name,
            Description = specialization.Description,
            IsActive = specialization.IsActive,
            TherapistCount = therapistCount,
            CreatedAtUtc = specialization.CreatedAtUtc,
            UpdatedAtUtc = specialization.UpdatedAtUtc
        };
    }

    private static string NormalizeName(
        string? value)
    {
        return value?.Trim() ?? string.Empty;
    }

    private static string? NormalizeDescription(
        string? value)
    {
        var normalized = value?.Trim();

        return string.IsNullOrWhiteSpace(normalized)
            ? null
            : normalized;
    }

    private static void ValidateName(
        string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new InvalidOperationException(
                "Specialization name is required.");
        }

        if (name.Length < 2)
        {
            throw new InvalidOperationException(
                "Specialization name must contain at least 2 characters.");
        }

        if (name.Length > 150)
        {
            throw new InvalidOperationException(
                "Specialization name may contain at most 150 characters.");
        }
    }
}