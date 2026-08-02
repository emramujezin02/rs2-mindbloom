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

        var therapists = await _context.Therapists
            .Where(x =>
                !x.IsDeleted &&
                x.SpecializationId == specialization.Id)
            .ToListAsync(cancellationToken);

        foreach (var therapist in therapists)
        {
            therapist.Specialization = name;
        }

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

    public async Task<IReadOnlyList<TherapyApproachResponseDto>>
    GetActiveTherapyApproachesAsync(
        CancellationToken cancellationToken = default)
    {
        return await _context.TherapyApproaches
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                x.IsActive)
            .OrderBy(x => x.Name)
            .Select(x =>
                new TherapyApproachResponseDto
                {
                    Id =
                        x.Id,

                    Name =
                        x.Name,

                    Description =
                        x.Description,

                    IsActive =
                        x.IsActive,

                    TherapistCount =
                        x.TherapistTherapyApproaches
                            .Count(link =>
                                !link.IsDeleted),

                    ClientCount =
                        x.ClientTherapyApproaches
                            .Count(link =>
                                !link.IsDeleted),

                    CreatedAtUtc =
                        x.CreatedAtUtc,

                    UpdatedAtUtc =
                        x.UpdatedAtUtc
                })
            .ToListAsync(
                cancellationToken);
    }

    public async Task<TherapyApproachPagedResponseDto>
        GetTherapyApproachesAsync(
            TherapyApproachQueryDto query,
            CancellationToken cancellationToken = default)
    {
        var pageNumber =
            query.PageNumber < 1
                ? 1
                : query.PageNumber;

        var pageSize =
            query.PageSize switch
            {
                < 1 => 10,
                > 100 => 100,
                _ => query.PageSize
            };

        var approaches =
            _context.TherapyApproaches
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted);

        if (!string.IsNullOrWhiteSpace(
                query.Search))
        {
            var normalizedSearch =
                query.Search.Trim();

            approaches =
                approaches.Where(x =>
                    x.Name.Contains(
                        normalizedSearch)
                    ||
                    (
                        x.Description != null &&
                        x.Description.Contains(
                            normalizedSearch)
                    ));
        }

        if (query.IsActive.HasValue)
        {
            approaches =
                approaches.Where(x =>
                    x.IsActive ==
                    query.IsActive.Value);
        }

        var totalCount =
            await approaches.CountAsync(
                cancellationToken);

        var items =
            await approaches
                .OrderBy(x => x.Name)
                .Skip(
                    (pageNumber - 1)
                    * pageSize)
                .Take(pageSize)
                .Select(x =>
                    new TherapyApproachResponseDto
                    {
                        Id =
                            x.Id,

                        Name =
                            x.Name,

                        Description =
                            x.Description,

                        IsActive =
                            x.IsActive,

                        TherapistCount =
                            x.TherapistTherapyApproaches
                                .Count(link =>
                                    !link.IsDeleted),

                        ClientCount =
                            x.ClientTherapyApproaches
                                .Count(link =>
                                    !link.IsDeleted),

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        UpdatedAtUtc =
                            x.UpdatedAtUtc
                    })
                .ToListAsync(
                    cancellationToken);

        return new TherapyApproachPagedResponseDto
        {
            Items =
                items,

            PageNumber =
                pageNumber,

            PageSize =
                pageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalCount == 0
                    ? 0
                    : (int)Math.Ceiling(
                        totalCount /
                        (double)pageSize)
        };
    }

    public async Task<TherapyApproachResponseDto>
        GetTherapyApproachByIdAsync(
            int id,
            CancellationToken cancellationToken = default)
    {
        var approach =
            await FindTherapyApproachAsync(
                id,
                cancellationToken);

        var therapistCount =
            await _context
                .TherapistTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        var clientCount =
            await _context
                .ClientTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        return MapTherapyApproachResponse(
            approach,
            therapistCount,
            clientCount);
    }

    public async Task<TherapyApproachResponseDto>
        CreateTherapyApproachAsync(
            CreateTherapyApproachDto request,
            CancellationToken cancellationToken = default)
    {
        var name =
            NormalizeName(
                request.Name);

        ValidateTherapyApproachName(
            name);

        var duplicateExists =
            await _context
                .TherapyApproaches
                .AnyAsync(
                    x =>
                        !x.IsDeleted &&
                        x.Name.ToLower() ==
                            name.ToLower(),
                    cancellationToken);

        if (duplicateExists)
        {
            throw new BusinessException(
                "A therapy approach with the same name already exists.");
        }

        var approach =
            new TherapyApproach
            {
                Name =
                    name,

                Description =
                    NormalizeDescription(
                        request.Description),

                IsActive =
                    request.IsActive
            };

        _context.TherapyApproaches.Add(
            approach);

        await _context.SaveChangesAsync(
            cancellationToken);

        return MapTherapyApproachResponse(
            approach,
            0,
            0);
    }

    public async Task<TherapyApproachResponseDto>
        UpdateTherapyApproachAsync(
            int id,
            UpdateTherapyApproachDto request,
            CancellationToken cancellationToken = default)
    {
        var approach =
            await FindTherapyApproachAsync(
                id,
                cancellationToken);

        var name =
            NormalizeName(
                request.Name);

        ValidateTherapyApproachName(
            name);

        var duplicateExists =
            await _context
                .TherapyApproaches
                .AnyAsync(
                    x =>
                        x.Id != id &&
                        !x.IsDeleted &&
                        x.Name.ToLower() ==
                            name.ToLower(),
                    cancellationToken);

        if (duplicateExists)
        {
            throw new BusinessException(
                "A therapy approach with the same name already exists.");
        }

        approach.Name =
            name;

        approach.Description =
            NormalizeDescription(
                request.Description);

        await _context.SaveChangesAsync(
            cancellationToken);

        var therapistCount =
            await _context
                .TherapistTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        var clientCount =
            await _context
                .ClientTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        return MapTherapyApproachResponse(
            approach,
            therapistCount,
            clientCount);
    }

    public async Task<TherapyApproachResponseDto>
        UpdateTherapyApproachStatusAsync(
            int id,
            UpdateTherapyApproachStatusDto request,
            CancellationToken cancellationToken = default)
    {
        var approach =
            await FindTherapyApproachAsync(
                id,
                cancellationToken);

        approach.IsActive =
            request.IsActive;

        await _context.SaveChangesAsync(
            cancellationToken);

        var therapistCount =
            await _context
                .TherapistTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        var clientCount =
            await _context
                .ClientTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        return MapTherapyApproachResponse(
            approach,
            therapistCount,
            clientCount);
    }

    public async Task DeleteTherapyApproachAsync(
        int id,
        CancellationToken cancellationToken = default)
    {
        var approach =
            await FindTherapyApproachAsync(
                id,
                cancellationToken);

        var therapistCount =
            await _context
                .TherapistTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        var clientCount =
            await _context
                .ClientTherapyApproaches
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.TherapyApproachId ==
                            approach.Id,
                    cancellationToken);

        if (therapistCount > 0 ||
            clientCount > 0)
        {
            throw new BusinessException(
                $"The therapy approach cannot be deleted because it is currently used by "
                + $"{therapistCount} therapist(s) and "
                + $"{clientCount} client(s). "
                + "Deactivate it instead.");
        }

        approach.IsDeleted =
            true;

        approach.IsActive =
            false;

        await _context.SaveChangesAsync(
            cancellationToken);
    }

    public async Task<
    IReadOnlyList<ArticleCategoryReferenceResponseDto>>
    GetActiveArticleCategoriesAsync(
        CancellationToken cancellationToken = default)
    {
        return await _context.ArticleCategories
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                x.IsActive)
            .OrderBy(x => x.Name)
            .Select(x =>
                new ArticleCategoryReferenceResponseDto
                {
                    Id =
                        x.Id,

                    Name =
                        x.Name,

                    Description =
                        x.Description,

                    IsActive =
                        x.IsActive,

                    ArticleCount =
                        x.Articles.Count(article =>
                            !article.IsDeleted),

                    CreatedAtUtc =
                        x.CreatedAtUtc,

                    UpdatedAtUtc =
                        x.UpdatedAtUtc
                })
            .ToListAsync(
                cancellationToken);
    }

    public async Task<
        ArticleCategoryReferencePagedResponseDto>
        GetArticleCategoriesAsync(
            ArticleCategoryReferenceQueryDto query,
            CancellationToken cancellationToken = default)
    {
        var pageNumber =
            query.PageNumber < 1
                ? 1
                : query.PageNumber;

        var pageSize =
            query.PageSize switch
            {
                < 1 => 10,
                > 100 => 100,
                _ => query.PageSize
            };

        var categories =
            _context.ArticleCategories
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted);

        if (!string.IsNullOrWhiteSpace(
                query.Search))
        {
            var search =
                query.Search.Trim();

            categories =
                categories.Where(x =>
                    x.Name.Contains(search)
                    ||
                    (
                        x.Description != null &&
                        x.Description.Contains(
                            search)
                    ));
        }

        if (query.IsActive.HasValue)
        {
            categories =
                categories.Where(x =>
                    x.IsActive ==
                    query.IsActive.Value);
        }

        var totalCount =
            await categories.CountAsync(
                cancellationToken);

        var items =
            await categories
                .OrderBy(x => x.Name)
                .Skip(
                    (pageNumber - 1)
                    * pageSize)
                .Take(pageSize)
                .Select(x =>
                    new ArticleCategoryReferenceResponseDto
                    {
                        Id =
                            x.Id,

                        Name =
                            x.Name,

                        Description =
                            x.Description,

                        IsActive =
                            x.IsActive,

                        ArticleCount =
                            x.Articles.Count(article =>
                                !article.IsDeleted),

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        UpdatedAtUtc =
                            x.UpdatedAtUtc
                    })
                .ToListAsync(
                    cancellationToken);

        return new ArticleCategoryReferencePagedResponseDto
        {
            Items =
                items,

            PageNumber =
                pageNumber,

            PageSize =
                pageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalCount == 0
                    ? 0
                    : (int)Math.Ceiling(
                        totalCount /
                        (double)pageSize)
        };
    }

    public async Task<
        ArticleCategoryReferenceResponseDto>
        GetArticleCategoryByIdAsync(
            int id,
            CancellationToken cancellationToken = default)
    {
        var category =
            await FindArticleCategoryAsync(
                id,
                cancellationToken);

        var articleCount =
            await _context.Articles
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.ArticleCategoryId ==
                            category.Id,
                    cancellationToken);

        return MapArticleCategoryResponse(
            category,
            articleCount);
    }

    public async Task<
        ArticleCategoryReferenceResponseDto>
        CreateArticleCategoryAsync(
            CreateArticleCategoryReferenceDto request,
            CancellationToken cancellationToken = default)
    {
        var name =
            NormalizeName(
                request.Name);

        ValidateArticleCategoryName(
            name);

        var duplicateExists =
            await _context
                .ArticleCategories
                .AnyAsync(
                    x =>
                        !x.IsDeleted &&
                        x.Name.ToLower() ==
                            name.ToLower(),
                    cancellationToken);

        if (duplicateExists)
        {
            throw new BusinessException(
                "An article category with the same name already exists.");
        }

        var category =
            new ArticleCategory
            {
                Name =
                    name,

                Description =
                    NormalizeDescription(
                        request.Description),

                IsActive =
                    request.IsActive
            };

        _context.ArticleCategories.Add(
            category);

        await _context.SaveChangesAsync(
            cancellationToken);

        return MapArticleCategoryResponse(
            category,
            0);
    }

    public async Task<
        ArticleCategoryReferenceResponseDto>
        UpdateArticleCategoryAsync(
            int id,
            UpdateArticleCategoryReferenceDto request,
            CancellationToken cancellationToken = default)
    {
        var category =
            await FindArticleCategoryAsync(
                id,
                cancellationToken);

        var name =
            NormalizeName(
                request.Name);

        ValidateArticleCategoryName(
            name);

        var duplicateExists =
            await _context
                .ArticleCategories
                .AnyAsync(
                    x =>
                        x.Id != id &&
                        !x.IsDeleted &&
                        x.Name.ToLower() ==
                            name.ToLower(),
                    cancellationToken);

        if (duplicateExists)
        {
            throw new BusinessException(
                "An article category with the same name already exists.");
        }

        category.Name =
            name;

        category.Description =
            NormalizeDescription(
                request.Description);

        await _context.SaveChangesAsync(
            cancellationToken);

        var articleCount =
            await _context.Articles
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.ArticleCategoryId ==
                            category.Id,
                    cancellationToken);

        return MapArticleCategoryResponse(
            category,
            articleCount);
    }

    public async Task<
        ArticleCategoryReferenceResponseDto>
        UpdateArticleCategoryStatusAsync(
            int id,
            UpdateArticleCategoryReferenceStatusDto request,
            CancellationToken cancellationToken = default)
    {
        var category =
            await FindArticleCategoryAsync(
                id,
                cancellationToken);

        category.IsActive =
            request.IsActive;

        await _context.SaveChangesAsync(
            cancellationToken);

        var articleCount =
            await _context.Articles
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.ArticleCategoryId ==
                            category.Id,
                    cancellationToken);

        return MapArticleCategoryResponse(
            category,
            articleCount);
    }

    public async Task DeleteArticleCategoryAsync(
        int id,
        CancellationToken cancellationToken = default)
    {
        var category =
            await FindArticleCategoryAsync(
                id,
                cancellationToken);

        var articleCount =
            await _context.Articles
                .CountAsync(
                    x =>
                        !x.IsDeleted &&
                        x.ArticleCategoryId ==
                            category.Id,
                    cancellationToken);

        if (articleCount > 0)
        {
            throw new BusinessException(
                $"The article category cannot be deleted because it is used by "
                + $"{articleCount} article(s). "
                + "Deactivate it instead.");
        }

        category.IsDeleted =
            true;

        category.IsActive =
            false;

        await _context.SaveChangesAsync(
            cancellationToken);
    }

    private async Task<ArticleCategory>
    FindArticleCategoryAsync(
        int id,
        CancellationToken cancellationToken)
    {
        var category =
            await _context.ArticleCategories
                .FirstOrDefaultAsync(
                    x =>
                        x.Id == id &&
                        !x.IsDeleted,
                    cancellationToken);

        if (category == null)
        {
            throw new NotFoundException(
                "Article category was not found.");
        }

        return category;
    }

    private static ArticleCategoryReferenceResponseDto
    MapArticleCategoryResponse(
        ArticleCategory category,
        int articleCount)
    {
        return new ArticleCategoryReferenceResponseDto
        {
            Id =
                category.Id,

            Name =
                category.Name,

            Description =
                category.Description,

            IsActive =
                category.IsActive,

            ArticleCount =
                articleCount,

            CreatedAtUtc =
                category.CreatedAtUtc,

            UpdatedAtUtc =
                category.UpdatedAtUtc
        };
    }

    private static void
    ValidateArticleCategoryName(
        string name)
    {
        if (string.IsNullOrWhiteSpace(
                name))
        {
            throw new BusinessException(
                "Article category name is required.");
        }

        if (name.Length < 2)
        {
            throw new BusinessException(
                "Article category name must contain at least 2 characters.");
        }

        if (name.Length > 150)
        {
            throw new BusinessException(
                "Article category name may contain at most 150 characters.");
        }
    }

    private async Task<TherapyApproach>
    FindTherapyApproachAsync(
        int id,
        CancellationToken cancellationToken)
    {
        var approach =
            await _context
                .TherapyApproaches
                .FirstOrDefaultAsync(
                    x =>
                        x.Id == id &&
                        !x.IsDeleted,
                    cancellationToken);

        if (approach == null)
        {
            throw new NotFoundException(
                "Therapy approach was not found.");
        }

        return approach;
    }

    private static TherapyApproachResponseDto
    MapTherapyApproachResponse(
        TherapyApproach approach,
        int therapistCount,
        int clientCount)
    {
        return new TherapyApproachResponseDto
        {
            Id =
                approach.Id,

            Name =
                approach.Name,

            Description =
                approach.Description,

            IsActive =
                approach.IsActive,

            TherapistCount =
                therapistCount,

            ClientCount =
                clientCount,

            CreatedAtUtc =
                approach.CreatedAtUtc,

            UpdatedAtUtc =
                approach.UpdatedAtUtc
        };
    }

    private static void
    ValidateTherapyApproachName(
        string name)
    {
        if (string.IsNullOrWhiteSpace(
                name))
        {
            throw new BusinessException(
                "Therapy approach name is required.");
        }

        if (name.Length < 2)
        {
            throw new BusinessException(
                "Therapy approach name must contain at least 2 characters.");
        }

        if (name.Length > 150)
        {
            throw new BusinessException(
                "Therapy approach name may contain at most 150 characters.");
        }
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