using System.Data;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Workshops.DTOs;
using MindBloom.Application.Features.Workshops.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Exceptions;

namespace MindBloom.Infrastructure.Services;

public class WorkshopService : IWorkshopService
{
    private const int MaximumPageSize = 50;

    private readonly ApplicationDbContext _context;

    public WorkshopService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResponse<WorkshopResponseDto>>
        GetPublicAsync(
            WorkshopQueryDto query,
            int? clientUserId)
    {
        var pageNumber =
            query.PageNumber < 1
                ? 1
                : query.PageNumber;

        var pageSize =
            query.PageSize < 1
                ? 10
                : Math.Min(
                    query.PageSize,
                    MaximumPageSize);

        int? clientId = null;

        if (clientUserId.HasValue)
        {
            clientId =
                await _context.Clients
                    .Where(x =>
                        x.UserId ==
                        clientUserId.Value)
                    .Select(x =>
                        (int?)x.Id)
                    .FirstOrDefaultAsync();
        }

        var workshops =
            _context.Workshops
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.Status ==
                        WorkshopStatus.Scheduled);

        workshops =
            ApplyFilters(
                workshops,
                query);

        var totalCount =
            await workshops.CountAsync();

        var currentClientId =
            clientId;

        var items =
            await workshops
                .OrderBy(x => x.StartUtc)
                .Skip(
                    (pageNumber - 1) *
                    pageSize)
                .Take(pageSize)
                .Select(x =>
                    new WorkshopResponseDto
                    {
                        Id = x.Id,
                        Title = x.Title,
                        Description =
                            x.Description,
                        StartUtc =
                            x.StartUtc,
                        EndUtc =
                            x.EndUtc,
                        Type =
                            x.Type.ToString(),
                        OnlineLink =
                            x.OnlineLink,
                        Location =
                            x.Location,
                        Capacity =
                            x.Capacity,
                        RegisteredCount =
                            x.Registrations.Count(r =>
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        AvailableSeats =
                            x.Capacity -
                            x.Registrations.Count(r =>
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        Price =
                            x.Price,
                        Status =
                            x.Status.ToString(),
                        OrganizerUserId =
                            x.OrganizerUserId,
                        OrganizerName =
                            x.OrganizerUser.FirstName
                            + " "
                            + x.OrganizerUser.LastName,
                        TherapistId =
                            x.TherapistId,
                        IsRegistered =
                            currentClientId.HasValue &&
                            x.Registrations.Any(r =>
                                r.ClientId ==
                                    currentClientId.Value &&
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        CreatedAtUtc =
                            x.CreatedAtUtc,
                        UpdatedAtUtc =
                            x.UpdatedAtUtc,
                        StatusChangeReason =
                            x.StatusChangeReason
                    })
                .ToListAsync();

        return CreatePagedResponse(
            items,
            pageNumber,
            pageSize,
            totalCount);
    }

    public async Task<WorkshopResponseDto>
        GetByIdAsync(
            int workshopId,
            int? clientUserId)
    {
        int? clientId = null;

        if (clientUserId.HasValue)
        {
            clientId =
                await _context.Clients
                    .Where(x =>
                        x.UserId ==
                        clientUserId.Value)
                    .Select(x =>
                        (int?)x.Id)
                    .FirstOrDefaultAsync();
        }

        var currentClientId =
            clientId;

        var result =
            await _context.Workshops
                .AsNoTracking()
                .Where(x =>
                    x.Id == workshopId &&
                    !x.IsDeleted)
                .Select(x =>
                    new WorkshopResponseDto
                    {
                        Id = x.Id,
                        Title = x.Title,
                        Description =
                            x.Description,
                        StartUtc =
                            x.StartUtc,
                        EndUtc =
                            x.EndUtc,
                        Type =
                            x.Type.ToString(),
                        OnlineLink =
                            x.OnlineLink,
                        Location =
                            x.Location,
                        Capacity =
                            x.Capacity,
                        RegisteredCount =
                            x.Registrations.Count(r =>
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        AvailableSeats =
                            x.Capacity -
                            x.Registrations.Count(r =>
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        Price =
                            x.Price,
                        Status =
                            x.Status.ToString(),
                        OrganizerUserId =
                            x.OrganizerUserId,
                        OrganizerName =
                            x.OrganizerUser.FirstName
                            + " "
                            + x.OrganizerUser.LastName,
                        TherapistId =
                            x.TherapistId,
                        IsRegistered =
                            currentClientId.HasValue &&
                            x.Registrations.Any(r =>
                                r.ClientId ==
                                    currentClientId.Value &&
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        CreatedAtUtc =
                            x.CreatedAtUtc,
                        UpdatedAtUtc =
                            x.UpdatedAtUtc,
                        StatusChangeReason =
                            x.StatusChangeReason
                    })
                .FirstOrDefaultAsync();

        if (result == null)
        {
            throw new NotFoundException(
                "Workshop not found.");
        }

        return result;
    }

    public async Task<PagedResponse<WorkshopResponseDto>>
        GetManageListAsync(
            int userId,
            bool isAdmin,
            WorkshopQueryDto query)
    {
        var pageNumber =
            query.PageNumber < 1
                ? 1
                : query.PageNumber;

        var pageSize =
            query.PageSize < 1
                ? 10
                : Math.Min(
                    query.PageSize,
                    MaximumPageSize);

        var workshops =
            _context.Workshops
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted);

        if (!isAdmin)
        {
            workshops =
                workshops.Where(x =>
                    x.OrganizerUserId ==
                    userId);
        }

        workshops =
            ApplyFilters(
                workshops,
                query);

        var totalCount =
            await workshops.CountAsync();

        var items =
            await workshops
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .Skip(
                    (pageNumber - 1) *
                    pageSize)
                .Take(pageSize)
                .Select(x =>
                    new WorkshopResponseDto
                    {
                        Id = x.Id,
                        Title = x.Title,
                        Description =
                            x.Description,
                        StartUtc =
                            x.StartUtc,
                        EndUtc =
                            x.EndUtc,
                        Type =
                            x.Type.ToString(),
                        OnlineLink =
                            x.OnlineLink,
                        Location =
                            x.Location,
                        Capacity =
                            x.Capacity,
                        RegisteredCount =
                            x.Registrations.Count(r =>
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        AvailableSeats =
                            x.Capacity -
                            x.Registrations.Count(r =>
                                !r.IsDeleted &&
                                r.Status ==
                                WorkshopRegistrationStatus
                                    .Registered),
                        Price =
                            x.Price,
                        Status =
                            x.Status.ToString(),
                        OrganizerUserId =
                            x.OrganizerUserId,
                        OrganizerName =
                            x.OrganizerUser.FirstName
                            + " "
                            + x.OrganizerUser.LastName,
                        TherapistId =
                            x.TherapistId,
                        IsRegistered =
                            false,
                        CreatedAtUtc =
                            x.CreatedAtUtc,
                        UpdatedAtUtc =
                            x.UpdatedAtUtc,
                        StatusChangeReason =
                            x.StatusChangeReason
                    })
                .ToListAsync();

        return CreatePagedResponse(
            items,
            pageNumber,
            pageSize,
            totalCount);
    }

    public async Task<WorkshopResponseDto>
        CreateAsync(
            int userId,
            bool isAdmin,
            CreateWorkshopDto request)
    {
        ValidateWorkshop(
            request.Title,
            request.Description,
            request.StartUtc,
            request.EndUtc,
            request.Type,
            request.OnlineLink,
            request.Location,
            request.Capacity,
            request.Price);

        var userExists =
            await _context.Users
                .AnyAsync(x =>
                    x.Id == userId);

        if (!userExists)
        {
            throw new NotFoundException(
                "Organizer not found.");
        }

        int? therapistId = null;

        if (isAdmin)
        {
            if (request.TherapistId.HasValue)
            {
                var therapistExists =
                    await _context.Therapists
                        .AnyAsync(x =>
                            x.Id ==
                            request.TherapistId.Value &&
                            !x.IsDeleted);

                if (!therapistExists)
                {
                    throw new NotFoundException(
                        "Selected therapist was not found.");
                }

                therapistId =
                    request.TherapistId;
            }
        }
        else
        {
            var therapist =
                await _context.Therapists
                    .FirstOrDefaultAsync(x =>
                        x.UserId == userId &&
                        !x.IsDeleted);

            if (therapist == null)
            {
                throw new NotFoundException(
                    "Therapist profile not found.");
            }

            therapistId =
                therapist.Id;
        }

        var workshop =
            new Workshop
            {
                Title =
                    request.Title.Trim(),
                Description =
                    request.Description.Trim(),
                StartUtc =
                    request.StartUtc,
                EndUtc =
                    request.EndUtc,
                Type =
                    request.Type,
                OnlineLink =
                    Normalize(
                        request.OnlineLink),
                Location =
                    Normalize(
                        request.Location),
                Capacity =
                    request.Capacity,
                Price =
                    request.Price,
                Status =
                    WorkshopStatus.Scheduled,
                OrganizerUserId =
                    userId,
                TherapistId =
                    therapistId
            };

        _context.Workshops.Add(
            workshop);

        await _context.SaveChangesAsync();

        return await GetByIdAsync(
            workshop.Id,
            null);
    }

    public async Task<WorkshopResponseDto>
        UpdateAsync(
            int userId,
            bool isAdmin,
            int workshopId,
            UpdateWorkshopDto request)
    {
        ValidateWorkshop(
            request.Title,
            request.Description,
            request.StartUtc,
            request.EndUtc,
            request.Type,
            request.OnlineLink,
            request.Location,
            request.Capacity,
            request.Price);

        var workshop =
            await GetWorkshopForManagementAsync(
                userId,
                isAdmin,
                workshopId);

        if (workshop.Status !=
            WorkshopStatus.Scheduled)
        {
            throw new BusinessException(
                "Only scheduled workshops can be edited.");
        }

        var registeredCount =
            await _context
                .WorkshopRegistrations
                .CountAsync(x =>
                    x.WorkshopId ==
                        workshopId &&
                    !x.IsDeleted &&
                    x.Status ==
                    WorkshopRegistrationStatus
                        .Registered);

        if (request.Capacity <
            registeredCount)
        {
            throw new BusinessException(
                $"Capacity cannot be lower than the current number of registered participants ({registeredCount}).");
        }

        if (isAdmin)
        {
            if (request.TherapistId.HasValue)
            {
                var therapistExists =
                    await _context.Therapists
                        .AnyAsync(x =>
                            x.Id ==
                            request.TherapistId.Value &&
                            !x.IsDeleted);

                if (!therapistExists)
                {
                    throw new NotFoundException(
                        "Selected therapist was not found.");
                }
            }

            workshop.TherapistId =
                request.TherapistId;
        }

        workshop.Title =
            request.Title.Trim();

        workshop.Description =
            request.Description.Trim();

        workshop.StartUtc =
            request.StartUtc;

        workshop.EndUtc =
            request.EndUtc;

        workshop.Type =
            request.Type;

        workshop.OnlineLink =
            Normalize(
                request.OnlineLink);

        workshop.Location =
            Normalize(
                request.Location);

        workshop.Capacity =
            request.Capacity;

        workshop.Price =
            request.Price;

        await _context.SaveChangesAsync();

        return await GetByIdAsync(
            workshop.Id,
            null);
    }

    public async Task<WorkshopResponseDto>
        UpdateStatusAsync(
            int userId,
            bool isAdmin,
            int workshopId,
            UpdateWorkshopStatusDto request)
    {
        var workshop =
            await GetWorkshopForManagementAsync(
                userId,
                isAdmin,
                workshopId);

        ValidateStatusTransition(
            workshop.Status,
            request.Status);

        if (request.Status ==
        WorkshopStatus.Completed &&
    workshop.EndUtc >
        DateTime.UtcNow)
        {
            throw new BusinessException(
                "A workshop cannot be completed before its scheduled end time.");
        }

        if (request.Status ==
                WorkshopStatus.Cancelled &&
            string.IsNullOrWhiteSpace(
                request.Reason))
        {
            throw new BadRequestException(
                "A cancellation reason is required.");
        }

        workshop.Status =
            request.Status;

        workshop.StatusChangedByUserId =
            userId;

        workshop.StatusChangedAtUtc =
            DateTime.UtcNow;

        workshop.StatusChangeReason =
            Normalize(
                request.Reason);

        await _context.SaveChangesAsync();

        return await GetByIdAsync(
            workshop.Id,
            null);
    }

    public async Task DeleteAsync(
        int userId,
        bool isAdmin,
        int workshopId)
    {
        var workshop =
            await GetWorkshopForManagementAsync(
                userId,
                isAdmin,
                workshopId);

        var hasRegistrations =
            await _context
                .WorkshopRegistrations
                .AnyAsync(x =>
                    x.WorkshopId ==
                        workshopId &&
                    !x.IsDeleted &&
                    x.Status ==
                    WorkshopRegistrationStatus
                        .Registered);

        if (hasRegistrations)
        {
            throw new BusinessException(
                "A workshop with active registrations cannot be deleted. Cancel the workshop instead.");
        }

        workshop.IsDeleted = true;

        await _context.SaveChangesAsync();
    }

    public async Task RegisterAsync(
        int clientUserId,
        int workshopId)
    {
        await using var transaction =
            await _context.Database
                .BeginTransactionAsync(
                    IsolationLevel.Serializable);

        try
        {
            var client =
                await _context.Clients
                    .FirstOrDefaultAsync(x =>
                        x.UserId ==
                        clientUserId &&
                        !x.IsDeleted);

            if (client == null)
            {
                throw new NotFoundException(
                    "Client profile not found.");
            }

            var workshop =
                await _context.Workshops
                    .FirstOrDefaultAsync(x =>
                        x.Id == workshopId &&
                        !x.IsDeleted);

            if (workshop == null)
            {
                throw new NotFoundException(
                    "Workshop not found.");
            }

            if (workshop.Status !=
                WorkshopStatus.Scheduled)
            {
                throw new BusinessException(
                    "Registration is available only for scheduled workshops.");
            }

            if (workshop.StartUtc <=
                DateTime.UtcNow)
            {
                throw new BusinessException(
                    "Registration is closed because the workshop has already started.");
            }

            var registeredCount =
                await _context
                    .WorkshopRegistrations
                    .CountAsync(x =>
                        x.WorkshopId ==
                            workshopId &&
                        !x.IsDeleted &&
                        x.Status ==
                        WorkshopRegistrationStatus
                            .Registered);

            if (registeredCount >=
                workshop.Capacity)
            {
                throw new BusinessException(
                    "The workshop has reached its maximum capacity.");
            }

            var existingRegistration =
                await _context
                    .WorkshopRegistrations
                    .FirstOrDefaultAsync(x =>
                        x.WorkshopId ==
                            workshopId &&
                        x.ClientId ==
                            client.Id);

            if (existingRegistration != null)
            {
                if (existingRegistration.Status ==
                    WorkshopRegistrationStatus
                        .Registered)
                {
                    throw new BusinessException(
                        "You are already registered for this workshop.");
                }

                existingRegistration.Status =
                    WorkshopRegistrationStatus
                        .Registered;

                existingRegistration.RegisteredAtUtc =
                    DateTime.UtcNow;

                existingRegistration.CancelledAtUtc =
                    null;

                existingRegistration.IsDeleted =
                    false;
            }
            else
            {
                var registration =
                    new WorkshopRegistration
                    {
                        WorkshopId =
                            workshopId,
                        ClientId =
                            client.Id,
                        Status =
                            WorkshopRegistrationStatus
                                .Registered,
                        RegisteredAtUtc =
                            DateTime.UtcNow
                    };

                _context.WorkshopRegistrations
                    .Add(registration);
            }

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task CancelRegistrationAsync(
        int clientUserId,
        int workshopId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                    clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        var workshop =
            await _context.Workshops
                .FirstOrDefaultAsync(x =>
                    x.Id == workshopId &&
                    !x.IsDeleted);

        if (workshop == null)
        {
            throw new NotFoundException(
                "Workshop not found.");
        }

        if (workshop.StartUtc <=
            DateTime.UtcNow)
        {
            throw new BusinessException(
                "Registration cannot be cancelled after the workshop has started.");
        }

        var registration =
            await _context
                .WorkshopRegistrations
                .FirstOrDefaultAsync(x =>
                    x.WorkshopId ==
                        workshopId &&
                    x.ClientId ==
                        client.Id &&
                    !x.IsDeleted &&
                    x.Status ==
                    WorkshopRegistrationStatus
                        .Registered);

        if (registration == null)
        {
            throw new NotFoundException(
                "Active workshop registration was not found.");
        }

        registration.Status =
            WorkshopRegistrationStatus
                .Cancelled;

        registration.CancelledAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    public async Task<PagedResponse<WorkshopResponseDto>>
        GetMyRegistrationsAsync(
            int clientUserId,
            int pageNumber,
            int pageSize)
    {
        pageNumber =
            pageNumber < 1
                ? 1
                : pageNumber;

        pageSize =
            pageSize < 1
                ? 10
                : Math.Min(
                    pageSize,
                    MaximumPageSize);

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                    clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        var query =
            _context.WorkshopRegistrations
                .AsNoTracking()
                .Where(x =>
                    x.ClientId ==
                        client.Id &&
                    !x.IsDeleted &&
                    x.Status ==
                    WorkshopRegistrationStatus
                        .Registered);

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderBy(x =>
                    x.Workshop.StartUtc)
                .Skip(
                    (pageNumber - 1) *
                    pageSize)
                .Take(pageSize)
                .Select(x =>
                    new WorkshopResponseDto
                    {
                        Id =
                            x.Workshop.Id,
                        Title =
                            x.Workshop.Title,
                        Description =
                            x.Workshop.Description,
                        StartUtc =
                            x.Workshop.StartUtc,
                        EndUtc =
                            x.Workshop.EndUtc,
                        Type =
                            x.Workshop.Type.ToString(),
                        OnlineLink =
                            x.Workshop.OnlineLink,
                        Location =
                            x.Workshop.Location,
                        Capacity =
                            x.Workshop.Capacity,
                        RegisteredCount =
                            x.Workshop.Registrations
                                .Count(r =>
                                    !r.IsDeleted &&
                                    r.Status ==
                                    WorkshopRegistrationStatus
                                        .Registered),
                        AvailableSeats =
                            x.Workshop.Capacity -
                            x.Workshop.Registrations
                                .Count(r =>
                                    !r.IsDeleted &&
                                    r.Status ==
                                    WorkshopRegistrationStatus
                                        .Registered),
                        Price =
                            x.Workshop.Price,
                        Status =
                            x.Workshop.Status.ToString(),
                        OrganizerUserId =
                            x.Workshop.OrganizerUserId,
                        OrganizerName =
                            x.Workshop.OrganizerUser
                                .FirstName
                            + " "
                            + x.Workshop.OrganizerUser
                                .LastName,
                        TherapistId =
                            x.Workshop.TherapistId,
                        IsRegistered =
                            true,
                        CreatedAtUtc =
                            x.Workshop.CreatedAtUtc,
                        UpdatedAtUtc =
                            x.Workshop.UpdatedAtUtc,
                        StatusChangeReason =
                            x.Workshop.StatusChangeReason
                    })
                .ToListAsync();

        return CreatePagedResponse(
            items,
            pageNumber,
            pageSize,
            totalCount);
    }

    private async Task<Workshop>
        GetWorkshopForManagementAsync(
            int userId,
            bool isAdmin,
            int workshopId)
    {
        var workshop =
            await _context.Workshops
                .FirstOrDefaultAsync(x =>
                    x.Id == workshopId &&
                    !x.IsDeleted);

        if (workshop == null)
        {
            throw new NotFoundException(
                "Workshop not found.");
        }

        if (!isAdmin &&
            workshop.OrganizerUserId !=
                userId)
        {
            throw new BusinessException(
                "You may manage only workshops that you organized.");
        }

        return workshop;
    }

    private static IQueryable<Workshop>
        ApplyFilters(
            IQueryable<Workshop> query,
            WorkshopQueryDto filter)
    {
        if (!string.IsNullOrWhiteSpace(
                filter.Search))
        {
            var search =
                filter.Search.Trim();

            query = query.Where(x =>
                x.Title.Contains(search) ||
                x.Description.Contains(search) ||
                x.OrganizerUser.FirstName
                    .Contains(search) ||
                x.OrganizerUser.LastName
                    .Contains(search));
        }

        if (filter.Type.HasValue)
        {
            query = query.Where(x =>
                x.Type ==
                filter.Type.Value);
        }

        if (filter.Status.HasValue)
        {
            query = query.Where(x =>
                x.Status ==
                filter.Status.Value);
        }

        if (filter.TherapistId.HasValue)
        {
            query = query.Where(x =>
                x.TherapistId ==
                filter.TherapistId.Value);
        }

        if (filter.FromUtc.HasValue)
        {
            query = query.Where(x =>
                x.StartUtc >=
                filter.FromUtc.Value);
        }

        if (filter.ToUtc.HasValue)
        {
            query = query.Where(x =>
                x.StartUtc <=
                filter.ToUtc.Value);
        }

        return query;
    }

    private static void ValidateWorkshop(
        string title,
        string description,
        DateTime startUtc,
        DateTime endUtc,
        WorkshopType type,
        string? onlineLink,
        string? location,
        int capacity,
        decimal price)
    {
        var normalizedTitle =
            title?.Trim() ??
            string.Empty;

        var normalizedDescription =
            description?.Trim() ??
            string.Empty;

        if (normalizedTitle.Length < 3 ||
            normalizedTitle.Length > 150)
        {
            throw new BadRequestException(
                "Title must contain between 3 and 150 characters.");
        }

        if (normalizedDescription.Length < 10 ||
            normalizedDescription.Length > 2000)
        {
            throw new BadRequestException(
                "Description must contain between 10 and 2000 characters.");
        }

        if (startUtc >= endUtc)
        {
            throw new BadRequestException(
                "Workshop start time must be before its end time.");
        }

        if (startUtc <= DateTime.UtcNow)
        {
            throw new BadRequestException(
                "Workshop must be scheduled in the future.");
        }

        if (capacity < 1 ||
            capacity > 10000)
        {
            throw new BadRequestException(
                "Capacity must be between 1 and 10000 participants.");
        }

        if (price < 0)
        {
            throw new BadRequestException(
                "Workshop price cannot be negative.");
        }

        if (!Enum.IsDefined(type))
        {
            throw new BadRequestException(
                "Select a valid workshop type.");
        }

        if (type ==
                WorkshopType.Online &&
            string.IsNullOrWhiteSpace(
                onlineLink))
        {
            throw new BadRequestException(
                "Online link is required for an online workshop.");
        }

        if (type ==
                WorkshopType.InPerson &&
            string.IsNullOrWhiteSpace(
                location))
        {
            throw new BadRequestException(
                "Location is required for an in-person workshop.");
        }

        if (!string.IsNullOrWhiteSpace(
                onlineLink))
        {
            var validUrl =
                Uri.TryCreate(
                    onlineLink.Trim(),
                    UriKind.Absolute,
                    out var uri) &&
                (
                    uri.Scheme ==
                        Uri.UriSchemeHttp ||
                    uri.Scheme ==
                        Uri.UriSchemeHttps
                );

            if (!validUrl)
            {
                throw new BadRequestException(
                    "Online link must be a valid HTTP or HTTPS URL.");
            }
        }
    }

    private static void
        ValidateStatusTransition(
            WorkshopStatus currentStatus,
            WorkshopStatus newStatus)
    {
        if (currentStatus == newStatus)
        {
            throw new BusinessException(
                "Workshop already has the selected status.");
        }

        var allowed =
            currentStatus switch
            {
                WorkshopStatus.Scheduled =>
                    newStatus ==
                        WorkshopStatus.Cancelled ||
                    newStatus ==
                        WorkshopStatus.Completed,

                WorkshopStatus.Cancelled =>
                    false,

                WorkshopStatus.Completed =>
                    false,

                _ => false
            };

        if (!allowed)
        {
            throw new BusinessException(
                $"Changing workshop status from {currentStatus} to {newStatus} is not allowed.");
        }

        if (newStatus ==
                WorkshopStatus.Completed &&
            currentStatus ==
                WorkshopStatus.Scheduled)
        {
            // Dodatna vremenska provjera radi se
            // u servisu prije snimanja po potrebi.
        }
    }

    private static string? Normalize(
        string? value)
    {
        return string.IsNullOrWhiteSpace(
                value)
            ? null
            : value.Trim();
    }

    private static PagedResponse<T>
        CreatePagedResponse<T>(
            List<T> items,
            int pageNumber,
            int pageSize,
            int totalCount)
    {
        return new PagedResponse<T>
        {
            Items = items,
            PageNumber =
                pageNumber,
            PageSize =
                pageSize,
            TotalCount =
                totalCount,
            TotalPages =
                (int)Math.Ceiling(
                    totalCount /
                    (double)pageSize)
        };
    }
}