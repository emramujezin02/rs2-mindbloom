using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Queries;
using MindBloom.Domain.Enums;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Shared.Observability;
using System.Data;
using MindBloom.Infrastructure.Time;
using Microsoft.EntityFrameworkCore.Storage;

namespace MindBloom.Infrastructure.Services;

public partial class AppointmentService : IAppointmentService
{
    private const int
    AppointmentBookingLockTimeoutMilliseconds =
        10000;

    private const string
        AppointmentSlotConflictMessage =
            "This appointment time has already been booked. "
            + "Please choose another available time.";
    private readonly ApplicationDbContext _context;
    private readonly TimeProvider _timeProvider;

    private const string ClientAppointmentConflictMessage =
        "You already have an active appointment during this time. Please choose another time.";

    private const string AppointmentBookingBusyMessage =
        "Appointment booking is busy. Please try again.";

    private readonly IPaymentService _paymentService;

    private readonly IMembershipService _membershipService;

    private readonly IOutboxWriter
    _outboxWriter;

    private readonly IIntegrationEventPublisher
    _integrationEventPublisher;

    private readonly ApplicationMetrics
    _applicationMetrics;

    private static bool IsValidStatusTransition(
    AppointmentStatus currentStatus,
    AppointmentStatus newStatus)
    {
        if (currentStatus == newStatus)
        {
            return false;
        }

        return currentStatus switch
        {
            AppointmentStatus.Pending =>
                newStatus == AppointmentStatus.Accepted
                || newStatus == AppointmentStatus.Rejected
                || newStatus == AppointmentStatus.Cancelled,

            AppointmentStatus.Accepted =>
                newStatus == AppointmentStatus.Completed
                || newStatus == AppointmentStatus.Cancelled,

            AppointmentStatus.Completed => false,

            AppointmentStatus.Cancelled => false,

            AppointmentStatus.Rejected => false,

            _ => false
        };
    }

    public AppointmentService(
        ApplicationDbContext context,
        IPaymentService paymentService,
        IMembershipService membershipService,
        ApplicationMetrics applicationMetrics,
        IIntegrationEventPublisher
            integrationEventPublisher,
        IOutboxWriter outboxWriter,
        TimeProvider? timeProvider = null)
    {
        _timeProvider = timeProvider ?? TimeProvider.System;
        _context =
            context;

        _paymentService =
            paymentService;

        _membershipService =
            membershipService;

        _integrationEventPublisher =
            integrationEventPublisher;

        _outboxWriter =
            outboxWriter;

        _applicationMetrics =
            applicationMetrics;
    }
    public async Task<AppointmentResponseDto>
     CreateAsync(
         int clientUserId,
         CreateAppointmentDto request)
    {
        var (localStart, localEnd) = AppointmentTimeZone.LocalInterval(request.StartUtc, request.EndUtc);

        var strategy =
            _context.Database
                .CreateExecutionStrategy();

        var result =
            await strategy.ExecuteAsync(
                async () =>
                {
                    // Participant application locks prevent competing inserts. Keep
                    // eligibility rows stable without Serializable's shared gap locks,
                    // which can deadlock independent bookings on empty index ranges.
                    await using var transaction =
                        await _context.Database
                            .BeginTransactionAsync(
                                System.Data
                                    .IsolationLevel
                                    .RepeatableRead);

                    try
                    {
                        // Same order in every booking, across all API instances.
                        // Acquire both before reading rows to avoid lock-order inversion.
                        await AcquireAppointmentBookingLockAsync(
                            $"MindBloom.AppointmentBooking.ClientUser.{clientUserId}");
                        await AcquireAppointmentBookingLockAsync(
                            $"MindBloom.AppointmentBooking.Therapist.{request.TherapistId}");

                        var therapist =
                            await _context.Therapists
                                .Include(x => x.User)
                                .FirstOrDefaultAsync(
                                    x =>
                                        x.Id ==
                                        request.TherapistId);

                        AppointmentBookingRules.EnsureTherapistEligible(therapist);

                        var dayOfWeek =
                            localStart.DayOfWeek;

                        var dailyAvailabilities =
                            await _context
                                .TherapistAvailabilities
                                .Where(
                                    x =>
                                        x.TherapistId ==
                                            request
                                                .TherapistId &&
                                        x.DayOfWeek ==
                                            dayOfWeek)
                                .ToListAsync();

                        var availability = dailyAvailabilities.FirstOrDefault(x =>
                            x.StartTime <= localStart.TimeOfDay &&
                            x.EndTime >= (localEnd.Date == localStart.Date
                                ? localEnd.TimeOfDay : TimeSpan.FromDays(1)))
                            ?? dailyAvailabilities.FirstOrDefault();

                        BusinessRuleGuard.Against(
                            availability == null,
                            "Therapist is not available on this day.");

                        if (availability == null)
                        {
                            throw new NotFoundException(
                                "Therapist availability was not found.");
                        }

                        var startTime =
                            localStart.TimeOfDay;

                        var endTime =
                            localEnd.TimeOfDay;

                        BusinessRuleGuard.Against(
                            startTime <
                                availability.StartTime ||
                            endTime >
                                availability.EndTime ||
                            (localEnd.Date != localStart.Date &&
                                !(localEnd == localStart.Date.AddDays(1) &&
                                    availability.EndTime == TimeSpan.FromDays(1))),
                            "Appointment is outside working hours.");

                        var unavailableDate =
                            await _context
                                .TherapistUnavailableDates
                                .AnyAsync(
                                    x =>
                                        x.TherapistId ==
                                            request
                                                .TherapistId &&
                                        request.StartUtc <
                                            x.EndUtc &&
                                        request.EndUtc >
                                            x.StartUtc);

                        BusinessRuleGuard.Against(
                            unavailableDate,
                            "Therapist is unavailable during this time.");

                        var overlappingAppointment =
                            await _context.Appointments
                                .AnyAsync(
                                    x =>
                                        x.TherapistId ==
                                            request
                                                .TherapistId &&
                                        request.StartUtc <
                                            x.EndUtc &&
                                        request.EndUtc >
                                            x.StartUtc &&
                                        (
                                            x.Status ==
                                                AppointmentStatus
                                                    .Pending ||
                                            x.Status ==
                                                AppointmentStatus
                                                    .Accepted
                                        ));

                        if (overlappingAppointment)
                        {
                            throw new BusinessException(
                                AppointmentSlotConflictMessage);
                        }

                        var client =
                            await _context.Clients
                                .FirstOrDefaultAsync(
                                    x =>
                                        x.UserId ==
                                            clientUserId &&
                                        !x.IsDeleted);

                        if (client == null)
                        {
                            throw new NotFoundException(
                                "Client profile not found.");
                        }

                        var clientHasOverlap = await _context.Appointments.AnyAsync(x =>
                            x.ClientId == client.Id &&
                            x.StartUtc < request.EndUtc && x.EndUtc > request.StartUtc &&
                            (x.Status == AppointmentStatus.Pending || x.Status == AppointmentStatus.Accepted));

                        if (clientHasOverlap)
                            throw new BusinessException(ClientAppointmentConflictMessage);

                        var appointment =
                            new Appointment
                            {
                                TherapistId =
                                    request.TherapistId,

                                StartUtc =
                                    request.StartUtc,

                                ClientId =
                                    client.Id,

                                EndUtc =
                                    request.EndUtc,

                                Status =
                                    AppointmentStatus
                                        .Pending,

                                Type =
                                    request.Type,

                                MeetingLink =
                                    string.IsNullOrWhiteSpace(
                                        request.MeetingLink)
                                        ? null
                                        : request
                                            .MeetingLink
                                            .Trim(),

                                Location =
                                    string.IsNullOrWhiteSpace(
                                        request.Location)
                                        ? null
                                        : request
                                            .Location
                                            .Trim(),

                                Notes =
                                    string.IsNullOrWhiteSpace(
                                        request.Notes)
                                        ? null
                                        : request
                                            .Notes
                                            .Trim(),

                                AppointmentDateUtc =
                                    request.StartUtc,

                                Price =
                                    therapist.HourlyRate
                            };

                        _context.Appointments.Add(
                            appointment);

                        await _context
                            .SaveChangesAsync();

                        _context
                            .AppointmentStatusAudits
                            .Add(
                                new AppointmentStatusAudit
                                {
                                    AppointmentId =
                                        appointment.Id,

                                    ChangedByUserId =
                                        clientUserId,

                                    PreviousStatus =
                                        null,

                                    NewStatus =
                                        AppointmentStatus
                                            .Pending,

                                    Action =
                                        "Created",

                                    Reason =
                                        "Appointment created by client.",

                                    ChangedAtUtc =
                                        DateTime.UtcNow
                                });

                        var appointmentCreatedEvent =
                            new AppointmentCreatedEvent
                            {
                                TimestampUtc =
                                    DateTime.UtcNow,

                                AppointmentId =
                                    appointment.Id,

                                ClientId =
                                    appointment.ClientId,

                                ClientUserId =
                                    clientUserId,

                                TherapistId =
                                    appointment
                                        .TherapistId,

                                TherapistUserId =
                                    therapist.UserId,

                                StartUtc =
                                    appointment.StartUtc,

                                EndUtc =
                                    appointment.EndUtc,

                                AppointmentType =
                                    appointment.Type
                                        .ToString(),

                                Status =
                                    appointment.Status
                                        .ToString(),

                                Price =
                                    appointment.Price
                            };

                        await _outboxWriter
                            .EnqueueAsync(
                                appointmentCreatedEvent,
                                IntegrationEventRoutingKeys
                                    .AppointmentCreated);

                        await _context
                            .SaveChangesAsync();

                        await transaction
                            .CommitAsync();

                        return new AppointmentResponseDto
                        {
                            Id =
                                appointment.Id,

                            TherapistId =
                                therapist.Id,

                            TherapistName =
                                therapist.User.FirstName
                                + " "
                                + therapist.User.LastName,

                            StartUtc =
                                appointment.StartUtc,

                            EndUtc =
                                appointment.EndUtc,

                            Status =
                                appointment.Status
                                    .ToString()
                        };
                    }
                    catch
                    {
                        await transaction
                            .RollbackAsync();

                        throw;
                    }
                });

        _applicationMetrics
            .RecordAppointmentCreated();

        return result;
    }

    private async Task
    AcquireAppointmentBookingLockAsync(
        string resource,
        CancellationToken cancellationToken =
            default)
    {
        var currentTransaction =
            _context.Database
                .CurrentTransaction;

        if (currentTransaction is null)
        {
            throw new InvalidOperationException(
                "Appointment booking lock requires "
                + "an active database transaction.");
        }

        var connection =
            _context.Database
                .GetDbConnection();

        if (connection.State !=
            ConnectionState.Open)
        {
            await connection.OpenAsync(
                cancellationToken);
        }

        await using var command =
            connection.CreateCommand();

        command.Transaction =
            currentTransaction
                .GetDbTransaction();

        command.CommandText =
            """
        DECLARE @result int;

        EXEC @result = sp_getapplock
            @Resource = @resource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = @timeout;

        SELECT @result;
        """;

        var resourceParameter =
            command.CreateParameter();

        resourceParameter.ParameterName =
            "@resource";

        resourceParameter.DbType =
            DbType.String;

        resourceParameter.Value =
            resource;

        command.Parameters.Add(
            resourceParameter);

        var timeoutParameter =
            command.CreateParameter();

        timeoutParameter.ParameterName =
            "@timeout";

        timeoutParameter.DbType =
            DbType.Int32;

        timeoutParameter.Value =
            AppointmentBookingLockTimeoutMilliseconds;

        command.Parameters.Add(
            timeoutParameter);

        var result =
            await command.ExecuteScalarAsync(
                cancellationToken);

        if (result is null ||
            !int.TryParse(
                result.ToString(),
                out var lockResult) ||
            lockResult < 0)
        {
            throw new BusinessException(
                AppointmentBookingBusyMessage);
        }
    }

    public async Task<PagedResponse<AppointmentResponseDto>>
     GetMyAppointmentsAsync(
         int userId,
         int pageNumber,
         int pageSize,
         string? status,
         DateTime? fromUtc,
         DateTime? toUtc)
    {
        await AutoCompleteAppointmentsAsync();
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId);

        if (client == null)
        {
            throw new NotFoundException("Client profile not found.");
        }

        var pagination =
            PaginationHelper.Normalize(
                pageNumber,
                pageSize);

        var query =
            _context.Appointments
            .AsNoTracking()
            .Include(x => x.Therapist)
                .ThenInclude(x => x.User)
            .Where(x =>
                x.ClientId == client.Id);

        query =
            ApplyAppointmentFilters(
                query,
                status,
                fromUtc,
                toUtc);

        query =
            query
            .OrderBy(x =>
                x.StartUtc)
            .ThenBy(x =>
                x.Id);

        var totalCount =
            await query.CountAsync();

        var appointments =
            await query
            .Skip(pagination.Skip)
            .Take(pagination.PageSize)
            .Select(x =>
                new AppointmentResponseDto
                {
                    Id = x.Id,

                    TherapistId =
                        x.TherapistId,

                    TherapistName =
                        x.Therapist.User.FirstName
                        + " "
                        + x.Therapist.User.LastName,

                    StartUtc =
                        x.StartUtc,

                    EndUtc =
                        x.EndUtc,

                    Status =
                        x.Status.ToString(),

                    Type =
                        x.Type.ToString(),

                    Price =
                        x.Price,

                    MeetingLink =
                        null,

                    ClientId =
    x.ClientId,

                    Notes =x.Notes,

                    Location =
                        x.Location,

                    PaymentId =
    x.Payment != null
        ? x.Payment.Id
        : null
                })
            .ToListAsync();

        return PagedResponse<AppointmentResponseDto>
            .Create(
                appointments,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }



    public async Task<PagedResponse<AppointmentResponseDto>>
    GetTherapistAppointmentsAsync(
        int therapistUserId,
        int pageNumber,
        int pageSize,
        string? status,
        DateTime? fromUtc,
        DateTime? toUtc,
        bool overlapsRange = false)
    {
        await AutoCompleteAppointmentsAsync();
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(
                    x => x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException("Therapist not found.");
        }

        var pagination =
            PaginationHelper.Normalize(
                pageNumber,
                pageSize);

        var query =
            _context.Appointments
            .AsNoTracking()
            .Include(x => x.Client)
            .ThenInclude(x => x.User)
            .Where(x => x.TherapistId == therapist.Id);

        if (overlapsRange)
        {
            // A local-day overview includes intervals starting on the preceding day.
            // The original start-based list contract remains the default.
            query = ApplyAppointmentFilters(query.Where(x => !x.IsDeleted), status, null, null);
            if (fromUtc.HasValue) query = query.Where(x => x.EndUtc > fromUtc.Value);
            if (toUtc.HasValue) query = query.Where(x => x.StartUtc < toUtc.Value);
        }
        else
        {
            query = ApplyAppointmentFilters(query, status, fromUtc, toUtc);
        }

        query =
            query
            .OrderBy(x => x.StartUtc)
            .ThenBy(x => x.Id);

        var totalCount =
            await query.CountAsync();

        var appointments =
            await query
            .Skip(pagination.Skip)
            .Take(pagination.PageSize)
            .Select(x => new AppointmentResponseDto
            {
                Id = x.Id,

                TherapistId = therapist.Id,

                TherapistName =
        x.Therapist.User.FirstName
        + " "
        + x.Therapist.User.LastName,

                ClientId = x.ClientId,

                ClientName =
        x.Client.User.FirstName
        + " "
        + x.Client.User.LastName,

                ClientEmail =
        x.Client.User.Email
        ?? string.Empty,

                StartUtc = x.StartUtc,

                EndUtc = x.EndUtc,

                Status = x.Status.ToString(),
                Type = x.Type.ToString(),

                Price = x.Price,

                MeetingLink = x.MeetingLink,

                Location = x.Location,

                Notes = x.Notes,

                PaymentId =
    x.Payment != null
        ? x.Payment.Id
        : null

            })
            .ToListAsync();

        return PagedResponse<AppointmentResponseDto>
            .Create(
                appointments,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    private static IQueryable<Appointment>
        ApplyAppointmentFilters(
            IQueryable<Appointment> query,
            string? status,
            DateTime? fromUtc,
            DateTime? toUtc)
    {
        if (!string.IsNullOrWhiteSpace(status) &&
            Enum.TryParse<AppointmentStatus>(
                status.Trim(),
                ignoreCase: true,
                out var parsedStatus))
        {
            query =
                query.Where(x =>
                    x.Status == parsedStatus);
        }

        if (fromUtc.HasValue)
        {
            query =
                query.Where(x =>
                    x.StartUtc >= fromUtc.Value);
        }

        if (toUtc.HasValue)
        {
            query =
                query.Where(x =>
                    x.StartUtc < toUtc.Value);
        }

        return query;
    }

    public async Task UpdateStatusAsync(
     int therapistUserId,
     UpdateAppointmentStatusDto request)
    {
        var strategy = _context.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(() => UpdateStatusUnderLockAsync(therapistUserId, request));
    }

    private async Task UpdateStatusUnderLockAsync(int therapistUserId, UpdateAppointmentStatusDto request)
    {
        await using var statusLock = await AppointmentStatusLock.AcquireAsync(_context, request.AppointmentId);
        var therapist =
            await _context.Therapists
                .Include(x =>
                    x.User)
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                        therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x =>
                    x.Client)
                .ThenInclude(x =>
                    x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        request.AppointmentId &&
                    x.TherapistId ==
                        therapist.Id);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        await _context.Entry(appointment).ReloadAsync();

        if (!IsValidStatusTransition(
          appointment.Status,
          request.Status))
        {
            throw new BusinessException(
                $"Status transition from {appointment.Status} to {request.Status} is not allowed.");
        }

        if (request.Status == AppointmentStatus.Completed &&
            appointment.EndUtc > _timeProvider.GetUtcNow().UtcDateTime)
        {
            throw new BusinessException(
                "An appointment can only be marked as completed after its scheduled end time.");
        }

        var reason = request.Reason?.Trim();
        if (request.Status == AppointmentStatus.Rejected &&
            (string.IsNullOrEmpty(reason) || reason.Length < 5 || reason.Length > UpdateAppointmentStatusDto.MaximumReasonLength))
        {
            throw new BadRequestException("Rejection reason must contain between 5 and 500 characters.");
        }

        await using var transaction = _context.Database.IsRelational() && _context.Database.CurrentTransaction == null
            ? await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable) : null;
        try
        {
        if (request.Status ==
            AppointmentStatus.Rejected)
        {
            await _membershipService
                .HandleAppointmentCancellationAsync(
                    appointment.Id,
                    reason!,
                    forceRestore: true);
        }

        if (request.Status ==
            AppointmentStatus.Completed)
        {
            await _membershipService
                .FinalizeAppointmentUsageAsync(
                    appointment.Id,
                    "Membership session consumed after the appointment was completed.");
        }
        var previousStatus =
    appointment.Status;

        appointment.Status =
    request.Status;

        _context.AppointmentStatusAudits.Add(
    new AppointmentStatusAudit
    {
        AppointmentId =
            appointment.Id,

        ChangedByUserId =
            therapistUserId,

        PreviousStatus =
            previousStatus,

        NewStatus =
            request.Status,

        Action =
            "TherapistStatusChange",

        Reason =
            request.Status switch
            {
                AppointmentStatus.Accepted =>
                    "Appointment accepted by therapist.",

                AppointmentStatus.Rejected =>
                    reason,

                AppointmentStatus.Completed =>
                    "Appointment completed by therapist.",

                _ =>
                    "Appointment status changed by therapist."
            },

        ChangedAtUtc =
            DateTime.UtcNow
    });

        var correlationId =
            Guid.NewGuid();

        switch (request.Status)
        {
            case AppointmentStatus.Accepted:
                {
                    var appointmentAcceptedEvent =
                        new AppointmentAcceptedEvent
                        {
                            CorrelationId =
                                correlationId,

                            TimestampUtc =
                                DateTime.UtcNow,

                            AppointmentId =
                                appointment.Id,

                            ClientId =
                                appointment.ClientId,

                            ClientUserId =
                                appointment.Client.UserId,

                            ClientEmail =
                                appointment.Client.User.Email
                                ?? string.Empty,

                            ClientName =
                                BuildFullName(
                                    appointment.Client.User.FirstName,
                                    appointment.Client.User.LastName),

                            TherapistId =
                                appointment.TherapistId,

                            TherapistUserId =
                                therapistUserId,

                            TherapistName =
                                BuildFullName(
                                    therapist.User.FirstName,
                                    therapist.User.LastName),

                            StartUtc =
                                appointment.StartUtc,

                            EndUtc =
                                appointment.EndUtc,

                            AppointmentType =
                                appointment.Type.ToString(),

                            MeetingLink =
                                appointment.MeetingLink,

                            Location =
                                appointment.Location
                        };

                    await _outboxWriter
                        .EnqueueAsync(
                            appointmentAcceptedEvent,
                            IntegrationEventRoutingKeys
                                .AppointmentAccepted);

                    break;
                }

            case AppointmentStatus.Rejected:
                {
                    var appointmentRejectedEvent =
                        new AppointmentRejectedEvent
                        {
                            CorrelationId =
                                correlationId,

                            TimestampUtc =
                                DateTime.UtcNow,

                            AppointmentId =
                                appointment.Id,

                            ClientId =
                                appointment.ClientId,

                            ClientUserId =
                                appointment.Client.UserId,

                            ClientEmail =
                                appointment.Client.User.Email
                                ?? string.Empty,

                            ClientName =
                                BuildFullName(
                                    appointment.Client.User.FirstName,
                                    appointment.Client.User.LastName),

                            TherapistId =
                                appointment.TherapistId,

                            TherapistUserId =
                                therapistUserId,

                            TherapistName =
                                BuildFullName(
                                    therapist.User.FirstName,
                                    therapist.User.LastName),

                            StartUtc =
                                appointment.StartUtc,

                            EndUtc =
                                appointment.EndUtc,

                            Reason =
                                reason!
                        };

                    await _outboxWriter
                        .EnqueueAsync(
                            appointmentRejectedEvent,
                            IntegrationEventRoutingKeys
                                .AppointmentRejected);

                    break;
                }

            case AppointmentStatus.Cancelled:
                {
                    var appointmentCancelledEvent =
                        new AppointmentCancelledEvent
                        {
                            CorrelationId =
                                correlationId,

                            TimestampUtc =
                                DateTime.UtcNow,

                            AppointmentId =
                                appointment.Id,

                            ClientId =
                                appointment.ClientId,

                            ClientUserId =
                                appointment.Client.UserId,

                            TherapistId =
                                appointment.TherapistId,

                            TherapistUserId =
                                therapistUserId,

                            CancelledByUserId =
                                therapistUserId,

                            PreviousStatus =
                                previousStatus.ToString(),

                            Reason =
                                "Appointment cancelled by therapist.",

                            StartUtc =
                                appointment.StartUtc,

                            EndUtc =
                                appointment.EndUtc
                        };

                    await _outboxWriter
                        .EnqueueAsync(
                            appointmentCancelledEvent,
                            IntegrationEventRoutingKeys
                                .AppointmentCancelled);

                    break;
                }

            case AppointmentStatus.Completed:
                {
                    var appointmentCompletedEvent =
                        new AppointmentCompletedEvent
                        {
                            CorrelationId =
                                correlationId,

                            TimestampUtc =
                                DateTime.UtcNow,

                            AppointmentId =
                                appointment.Id,

                            ClientId =
                                appointment.ClientId,

                            ClientUserId =
                                appointment.Client.UserId,

                            TherapistId =
                                appointment.TherapistId,

                            TherapistUserId =
                                therapistUserId,

                            StartUtc =
                                appointment.StartUtc,

                            EndUtc =
                                appointment.EndUtc,

                            CompletedByUserId =
                                therapistUserId,

                            AppointmentType =
                                appointment.Type.ToString(),

                            Price =
                                appointment.Price,

                            IsPaid =
                                appointment.IsPaid
                        };

                    await _outboxWriter
                        .EnqueueAsync(
                            appointmentCompletedEvent,
                            IntegrationEventRoutingKeys
                                .AppointmentCompleted);

                    break;
                }
        }
        await _context.SaveChangesAsync();
        if (transaction != null) await transaction.CommitAsync();
        }
        catch
        {
            if (transaction != null) await transaction.RollbackAsync();
            _context.ChangeTracker.Clear();
            throw;
        }
    }

    public async Task CancelAppointmentAsync(
    int clientUserId,
    int appointmentId,
    CancelAppointmentDto request)
    {
        await using var statusLock = await AppointmentStatusLock.AcquireAsync(_context, appointmentId);
        var reason =
            request.Reason?.Trim() ??
            string.Empty;



        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                        clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x =>
                    x.Therapist)
                .ThenInclude(x =>
                    x.User)
                .Include(x =>
                    x.Payment)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        appointmentId &&
                    x.ClientId ==
                        client.Id);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        await _context.Entry(appointment).ReloadAsync();

        if (appointment.Status ==
            AppointmentStatus.Completed)
        {
            throw new BusinessException(
    "A completed appointment cannot be cancelled.");
        }

        if (appointment.Status ==
            AppointmentStatus.Rejected)
        {
            throw new BusinessException(
    "A rejected appointment cannot be cancelled.");
        }

        if (!IsValidStatusTransition(
        appointment.Status,
        AppointmentStatus.Cancelled))
        {
            throw new BusinessException(
                $"Status transition from {appointment.Status} to Cancelled is not allowed.");
        }

        if (appointment.Status ==
            AppointmentStatus.Cancelled)
        {
            await _membershipService
                .HandleAppointmentCancellationAsync(
                    appointmentId,
                    reason,
                    forceRestore: false);

            if (appointment.Payment != null)
            {
                await _paymentService
                    .RefundAppointmentPaymentAsync(
                        clientUserId,
                        appointmentId,
                        reason);
            }

            return;
        }

        await _membershipService
            .HandleAppointmentCancellationAsync(
                appointmentId,
                reason,
                forceRestore: false);

        if (appointment.Payment != null &&
            (appointment.Payment.Status ==
                 PaymentStatus.Paid ||
             appointment.Payment.Status ==
                 PaymentStatus.RefundPending ||
             appointment.Payment.Status ==
                 PaymentStatus.RefundFailed ||
             appointment.Payment.Status ==
                 PaymentStatus.Refunded))
        {
            await _paymentService
                .RefundAppointmentPaymentAsync(
                    clientUserId,
                    appointmentId,
                    reason);
        }
        var previousStatus =
    appointment.Status;

        appointment.Status =
    AppointmentStatus.Cancelled;

        _context.AppointmentStatusAudits.Add(
    new AppointmentStatusAudit
    {
        AppointmentId =
            appointment.Id,

        ChangedByUserId =
            clientUserId,

        PreviousStatus =
            previousStatus,

        NewStatus =
            AppointmentStatus.Cancelled,

        Action =
            "ClientCancellation",

        Reason =
            reason,

        ChangedAtUtc =
            DateTime.UtcNow
    });

        await _context.SaveChangesAsync();

        var correlationId =
            Guid.NewGuid();

        var appointmentCancelledEvent =
            new AppointmentCancelledEvent
            {
                CorrelationId =
                    correlationId,

                TimestampUtc =
                    DateTime.UtcNow,

                AppointmentId =
                    appointment.Id,

                ClientId =
                    appointment.ClientId,

                ClientUserId =
                    clientUserId,

                TherapistId =
                    appointment.TherapistId,

                TherapistUserId =
                    appointment.Therapist.UserId,

                CancelledByUserId =
                    clientUserId,

                PreviousStatus =
                    previousStatus.ToString(),

                Reason =
                    reason,

                StartUtc =
                    appointment.StartUtc,

                EndUtc =
                    appointment.EndUtc
            };

        await _integrationEventPublisher
            .PublishAsync(
                appointmentCancelledEvent,
                IntegrationEventRoutingKeys
                    .AppointmentCancelled);

    }

    public async Task<TherapistStatsDto>
    GetTherapistStatsAsync(
        int therapistUserId)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId && !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException("Therapist not found.");
        }

        var totalAppointments =
     await _context.Appointments
         .CountAsync(x =>
             !x.IsDeleted && x.TherapistId == therapist.Id);

        var completedAppointments =
            await _context.Appointments
                .CountAsync(x =>
                    !x.IsDeleted && x.TherapistId == therapist.Id
                    && x.Status ==
                        AppointmentStatus.Completed);

        var cancelledAppointments =
            await _context.Appointments
                .CountAsync(x =>
                    !x.IsDeleted && x.TherapistId == therapist.Id
                    && x.Status ==
                        AppointmentStatus.Cancelled);

        decimal totalEarnings =
            await DashboardFinancialQueries.TherapistDirectReceipts(_context, therapist.Id)
                .SumAsync(p => (decimal?)p.Amount) ?? 0;

        return new TherapistStatsDto
        {
            TotalAppointments =
                totalAppointments,

            CompletedAppointments =
                completedAppointments,

            CancelledAppointments =
                cancelledAppointments,

            TotalEarnings =
                totalEarnings
        };

    }

    public async Task AddAppointmentNoteAsync(
    int therapistUserId,
    CreateAppointmentNoteDto request)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId
                    && x.TherapistId == therapist.Id);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        if (appointment.Status
            != AppointmentStatus.Completed)
        {
            throw new BusinessException(
                "Notes can only be added after completed appointments.");
        }

        var existingNote =
            await _context.AppointmentNotes
                .FirstOrDefaultAsync(x =>
                    x.AppointmentId
                        == request.AppointmentId);

        if (existingNote != null)
        {
            throw new BusinessException(
                "Appointment note already exists.");
        }

        var note =
            new AppointmentNote
            {
                AppointmentId =
                    appointment.Id,

                TherapistId =
                    therapist.Id,

                Notes =
                    request.Notes,

                ClientMood =
                    request.ClientMood,

                Recommendations =
                    request.Recommendations,

                FollowUpNeeded =
                    request.FollowUpNeeded
            };

        _context.AppointmentNotes.Add(note);

        await _context.SaveChangesAsync();
    }

    public async Task<
    AppointmentNoteResponseDto?>
    GetAppointmentNoteAsync(
        int therapistUserId,
        int appointmentId)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        return await _context.AppointmentNotes.AsNoTracking()
            .Where(x =>
                x.AppointmentId == appointmentId
                && x.TherapistId == therapist.Id)
            .Select(x =>
                new AppointmentNoteResponseDto
                {
                    Id = x.Id,

                    AppointmentId =
                        x.AppointmentId,

                    Notes =
                        x.Notes,

                    ClientMood =
                        x.ClientMood,

                    Recommendations =
                        x.Recommendations,

                    FollowUpNeeded =
                        x.FollowUpNeeded,

                    CreatedAtUtc =
                        x.CreatedAtUtc
                })
            .FirstOrDefaultAsync();
    }

    public async Task<ClientDashboardDto>
    GetClientDashboardAsync(
        int clientUserId)
    {
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointments = _context.Appointments.AsNoTracking()
            .Where(x => x.ClientId == client.Id && !x.IsDeleted);
        var completed = appointments.Where(x => x.Status == AppointmentStatus.Completed);

        var dashboard = new ClientDashboardDto
        {
            TotalAppointments = await appointments.CountAsync(),
            CompletedAppointments = await completed.CountAsync(),
            PendingAppointments = await appointments.CountAsync(x => x.Status == AppointmentStatus.Pending),
            CancelledAppointments = await appointments.CountAsync(x => x.Status == AppointmentStatus.Cancelled || x.Status == AppointmentStatus.Rejected),
            TotalTherapistsVisited = await completed.Select(x => x.TherapistId).Distinct().CountAsync(),
            TotalSpent = await DashboardFinancialQueries.ClientTotalSpentAsync(_context, client.Id),
            LastAppointmentDate = await completed.Where(x => x.EndUtc <= nowUtc)
                .OrderByDescending(x => x.EndUtc).ThenByDescending(x => x.Id)
                .Select(x => (DateTime?)x.EndUtc).FirstOrDefaultAsync(),
            NextAppointmentDate = await appointments
                .Where(x => (x.Status == AppointmentStatus.Pending || x.Status == AppointmentStatus.Accepted) && x.StartUtc > nowUtc)
                .OrderBy(x => x.StartUtc).ThenBy(x => x.Id)
                .Select(x => (DateTime?)x.StartUtc).FirstOrDefaultAsync()
        };
        // SQL datetime2 stores UTC ticks without a DateTime.Kind; retain the UTC API contract.
        if (dashboard.LastAppointmentDate.HasValue)
            dashboard.LastAppointmentDate = DateTime.SpecifyKind(dashboard.LastAppointmentDate.Value, DateTimeKind.Utc);
        if (dashboard.NextAppointmentDate.HasValue)
            dashboard.NextAppointmentDate = DateTime.SpecifyKind(dashboard.NextAppointmentDate.Value, DateTimeKind.Utc);
        return dashboard;
    }

    public async Task UpdateMeetingLinkAsync(
    int therapistUserId,
    int appointmentId,
    UpdateMeetingLinkDto request)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId
                    && x.TherapistId
                    == therapist.Id);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        if (appointment.Type
            != AppointmentType.Online)
        {
            throw new BusinessException(
                "Meeting link can only be added to online appointments.");
        }

        if (appointment.Status !=
    AppointmentStatus.Accepted)
        {
            throw new BusinessException(
                "Meeting link can only be updated for an accepted appointment.");
        }

        appointment.MeetingLink =
            request.MeetingLink;

        await _context.SaveChangesAsync();
    }

    public async Task<List<OccupiedAppointmentSlotDto>>
    GetOccupiedSlotsAsync(
        int therapistId,
        DateTime date)
    {
        var therapistExists =
            await _context.Therapists
                .Where(TherapistVisibility.PubliclyVisible)
                .AnyAsync(x => x.Id == therapistId);

        if (!therapistExists)
        {
            throw new NotFoundException(
                "Therapist not found or is not available.");
        }

        var (dateUtc, nextDateUtc) = AppointmentTimeZone.DayBounds(date);

        return await _context.Appointments
            .AsNoTracking()
            .Where(x =>
                x.TherapistId == therapistId &&
                x.StartUtc < nextDateUtc &&
                x.EndUtc > dateUtc &&
                (
                    x.Status == AppointmentStatus.Pending ||
                    x.Status == AppointmentStatus.Accepted
                ))
            .OrderBy(x => x.StartUtc)
            .Select(x =>
                new OccupiedAppointmentSlotDto
                {
                    StartUtc = DateTime.SpecifyKind(x.StartUtc, DateTimeKind.Utc),
                    EndUtc = DateTime.SpecifyKind(x.EndUtc, DateTimeKind.Utc)
                })
            .ToListAsync();
    }

    public async Task<AppointmentResponseDto>
    GetClientAppointmentDetailsAsync(
        int clientUserId,
        int appointmentId)
    {
        await AutoCompleteAppointmentsAsync();

        var client =
            await _context.Clients
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client profile not found.");
        }

        var appointment =
            await _context.Appointments
                .AsNoTracking()
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Payment)
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId &&
                    x.ClientId == client.Id);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        var nowUtc = DateTime.UtcNow;

        var accessOpensAtUtc =
            appointment.StartUtc.AddMinutes(-15);

        var isOnline =
            appointment.Type ==
            AppointmentType.Online;

        var isAccepted =
            appointment.Status ==
            AppointmentStatus.Accepted;

        var isInsideAccessWindow =
            nowUtc >= accessOpensAtUtc &&
            nowUtc <= appointment.EndUtc;

        var hasMeetingLink =
            !string.IsNullOrWhiteSpace(
                appointment.MeetingLink);

        var canAccessSession =
            isOnline &&
            isAccepted &&
            isInsideAccessWindow &&
            hasMeetingLink;

        string? sessionAccessMessage;

        if (!isOnline)
        {
            sessionAccessMessage =
                "This is an in-person appointment.";
        }
        else if (appointment.Status ==
                 AppointmentStatus.Cancelled)
        {
            sessionAccessMessage =
                "The online session is unavailable because the appointment was cancelled.";
        }
        else if (appointment.Status ==
                 AppointmentStatus.Rejected)
        {
            sessionAccessMessage =
                "The online session is unavailable because the appointment was rejected.";
        }
        else if (appointment.Status ==
                 AppointmentStatus.Pending)
        {
            sessionAccessMessage =
                "The therapist must accept the appointment before the online session becomes available.";
        }
        else if (appointment.Status ==
                 AppointmentStatus.Completed ||
                 nowUtc > appointment.EndUtc)
        {
            sessionAccessMessage =
                "The online session has ended.";
        }
        else if (nowUtc < accessOpensAtUtc)
        {
            sessionAccessMessage =
                "The online session becomes available 15 minutes before the appointment starts.";
        }
        else if (!hasMeetingLink)
        {
            sessionAccessMessage =
                "The therapist has not added the online session link yet.";
        }
        else
        {
            sessionAccessMessage = null;
        }

        return new AppointmentResponseDto
        {
            Id = appointment.Id,

            TherapistId =
                appointment.TherapistId,

            TherapistName =
                appointment.Therapist.User.FirstName
                + " "
                + appointment.Therapist.User.LastName,

            StartUtc =
                appointment.StartUtc,

            EndUtc =
                appointment.EndUtc,

            Status =
                appointment.Status.ToString(),

            Type =
                appointment.Type.ToString(),

            Price =
                appointment.Price,

            MeetingLink =
                canAccessSession
                    ? appointment.MeetingLink
                    : null,

            Location =
                appointment.Location,

            Notes =
                appointment.Notes,

            CanAccessSession =
                canAccessSession,

            SessionAccessMessage =
                sessionAccessMessage,

            PaymentId =
                appointment.Payment != null
                    ? appointment.Payment.Id
                    : null,

            ClientId =
                appointment.ClientId
        };
    }

    private static string BuildFullName(
    string? firstName,
    string? lastName)
    {
        return
            $"{firstName} {lastName}"
                .Trim();
    }
}


