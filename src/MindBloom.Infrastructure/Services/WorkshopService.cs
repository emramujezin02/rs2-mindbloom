using System.Data;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Workshops.DTOs;
using MindBloom.Application.Features.Workshops.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Pagination;

namespace MindBloom.Infrastructure.Services;

public class WorkshopService : IWorkshopService
{
    private readonly ApplicationDbContext _context;

    private readonly IBusinessNotificationService
    _businessNotificationService;

    public WorkshopService(
    ApplicationDbContext context,
    IBusinessNotificationService
        businessNotificationService)
    {
        _context =
            context;

        _businessNotificationService =
            businessNotificationService;
    }

    public async Task<PagedResponse<WorkshopResponseDto>>
        GetPublicAsync(
            WorkshopQueryDto query,
            int? clientUserId)
    {
        var pagination =
            PaginationHelper.Normalize(
                query.PageNumber,
                query.PageSize);

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

        var currentUtc =
    DateTime.UtcNow;

        var items =
            await workshops
                .OrderBy(x => x.StartUtc)
.Skip(
    pagination.Skip)
.Take(
    pagination.PageSize)
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
    currentClientId.HasValue
    && x.Type ==
        WorkshopType.Online
    && x.Status ==
        WorkshopStatus.Scheduled
    && x.StartUtc <=
        currentUtc.AddMinutes(15)
    && x.EndUtc >
        currentUtc
    && x.Registrations.Any(r =>
        r.ClientId ==
            currentClientId.Value
        && !r.IsDeleted
        && r.Status ==
            WorkshopRegistrationStatus
                .Registered)
        ? x.OnlineLink
        : null,
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

        return PagedResponse<WorkshopResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
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

        var currentUtc =
    DateTime.UtcNow;

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
    currentClientId.HasValue
    && x.Type ==
        WorkshopType.Online
    && x.Status ==
        WorkshopStatus.Scheduled
    && x.StartUtc <=
        currentUtc.AddMinutes(15)
    && x.EndUtc >
        currentUtc
    && x.Registrations.Any(r =>
        r.ClientId ==
            currentClientId.Value
        && !r.IsDeleted
        && r.Status ==
            WorkshopRegistrationStatus
                .Registered)
        ? x.OnlineLink
        : null,
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
        var pagination =
            PaginationHelper.Normalize(
                query.PageNumber,
                query.PageSize);

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
    pagination.Skip)
.Take(
    pagination.PageSize)
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

        return PagedResponse<WorkshopResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<WorkshopResponseDto>
        CreateAsync(
            int userId,
            bool isAdmin,
            CreateWorkshopDto request)
    {


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

        var workshopTitle =
            string.Empty;

        var organizerUserId =
            0;

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

            workshopTitle =
                workshop.Title;

            organizerUserId =
                workshop.OrganizerUserId;

            BusinessRuleGuard.Against(
                workshop.Status !=
                    WorkshopStatus.Scheduled,
                "Registration is available only for scheduled workshops.");

            BusinessRuleGuard.Against(
                workshop.StartUtc <=
                    DateTime.UtcNow,
                "Registration is closed because the workshop has already started.");

            var existingRegistration =
                await _context
                    .WorkshopRegistrations
                    .FirstOrDefaultAsync(x =>
                        x.WorkshopId ==
                            workshopId &&
                        x.ClientId ==
                            client.Id);

            BusinessRuleGuard.Against(
                existingRegistration?.Status ==
                    WorkshopRegistrationStatus.Registered &&
                !existingRegistration.IsDeleted,
                "You are already registered for this workshop.");

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

            BusinessRuleGuard.Against(
                registeredCount >=
                    workshop.Capacity,
                "The workshop has reached its maximum capacity.");

            if (existingRegistration != null)
            {
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

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException exception)
            {
                throw new BusinessException(
                    "You are already registered for this workshop.",
                    exception);
            }

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }

        await _businessNotificationService
            .PublishAsync(
                clientUserId,
                "Workshop registration confirmed",
                $"You have successfully registered for \"{workshopTitle}\".");

        if (organizerUserId > 0 &&
            organizerUserId != clientUserId)
        {
            await _businessNotificationService
                .PublishAsync(
                    organizerUserId,
                    "New workshop registration",
                    $"A new participant registered for \"{workshopTitle}\".");
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
                    x.Id ==
                        workshopId &&
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
            WorkshopRegistrationStatus.Cancelled;

        registration.CancelledAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync();

        await _businessNotificationService
            .PublishAsync(
                clientUserId,
                "Workshop registration cancelled",
                $"Your registration for "
                + $"\"{workshop.Title}\" "
                + "has been cancelled.");

        if (workshop.OrganizerUserId > 0 &&
            workshop.OrganizerUserId !=
                clientUserId)
        {
            await _businessNotificationService
                .PublishAsync(
                    workshop.OrganizerUserId,
                    "Workshop registration cancelled",
                    $"A participant cancelled their registration for "
                    + $"\"{workshop.Title}\".");
        }
    }

    public async Task<PagedResponse<WorkshopResponseDto>>
        GetMyRegistrationsAsync(
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

        var totalCount = await query.CountAsync();

        var currentUtc = DateTime.UtcNow;

        var items =
            await query
                .OrderBy(x =>
                    x.Workshop.StartUtc)
.Skip(
    pagination.Skip)
.Take(
    pagination.PageSize)
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
    x.Workshop.Type ==
        WorkshopType.Online
    && x.Workshop.Status ==
        WorkshopStatus.Scheduled
    && x.Workshop.StartUtc <=
        currentUtc.AddMinutes(15)
    && x.Workshop.EndUtc >
        currentUtc
        ? x.Workshop.OnlineLink
        : null,
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

        return PagedResponse<WorkshopResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<
    PagedResponse<WorkshopRegistrationResponseDto>>
    GetRegistrationsAsync(
        int userId,
        bool isAdmin,
        int workshopId,
        int pageNumber,
        int pageSize)
    {
        var pagination =
            PaginationHelper.Normalize(
                pageNumber,
                pageSize);

        await GetWorkshopForManagementAsync(
            userId,
            isAdmin,
            workshopId);

        var query =
            _context.WorkshopRegistrations
                .AsNoTracking()
                .Where(x =>
                    x.WorkshopId ==
                        workshopId &&
                    !x.IsDeleted);

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.RegisteredAtUtc)
.Skip(
    pagination.Skip)
.Take(
    pagination.PageSize)
                .Select(x =>
                    new WorkshopRegistrationResponseDto
                    {
                        Id =
                            x.Id,

                        WorkshopId =
                            x.WorkshopId,

                        ClientId =
                            x.ClientId,

                        ClientUserId =
                            x.Client.UserId,

                        ClientName =
                            x.Client.User.FirstName
                            + " "
                            + x.Client.User.LastName,

                        ClientEmail =
                            x.Client.User.Email
                            ?? string.Empty,

                        Status =
                            x.Status.ToString(),

                        RegisteredAtUtc =
                            x.RegisteredAtUtc,

                        CancelledAtUtc =
                            x.CancelledAtUtc
                    })
                .ToListAsync();

        return PagedResponse<
                WorkshopRegistrationResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
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

        BusinessRuleGuard.AgainstNotOwned(
            isAdmin ||
            workshop.OrganizerUserId == userId,
            "You may manage only workshops that you organized.");

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

   
}