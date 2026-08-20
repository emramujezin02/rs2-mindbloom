using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Domain.Enums;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Shared.Observability;
using System.Data;
using Microsoft.EntityFrameworkCore.Storage;

namespace MindBloom.Infrastructure.Services;

public class AppointmentService : IAppointmentService
{
    private const int
    AppointmentBookingLockTimeoutMilliseconds =
        10000;

    private const string
        AppointmentSlotConflictMessage =
            "This appointment time has already been booked. "
            + "Please choose another available time.";
    private readonly ApplicationDbContext _context;

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
        IOutboxWriter outboxWriter)
    {
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
        var strategy =
            _context.Database
                .CreateExecutionStrategy();

        var result =
            await strategy.ExecuteAsync(
                async () =>
                {
                    await using var transaction =
                        await _context.Database
                            .BeginTransactionAsync(
                                System.Data
                                    .IsolationLevel
                                    .Serializable);

                    try
                    {
                        await AcquireAppointmentBookingLockAsync(
    request.TherapistId);

                        var therapist =
                            await _context.Therapists
                                .Include(x => x.User)
                                .FirstOrDefaultAsync(
                                    x =>
                                        x.Id ==
                                        request.TherapistId);

                        if (therapist == null)
                        {
                            throw new NotFoundException(
                                "Therapist not found.");
                        }

                        var dayOfWeek =
                            request.StartUtc
                                .DayOfWeek;

                        var availability =
                            await _context
                                .TherapistAvailabilities
                                .FirstOrDefaultAsync(
                                    x =>
                                        x.TherapistId ==
                                            request
                                                .TherapistId &&
                                        x.DayOfWeek ==
                                            dayOfWeek);

                        BusinessRuleGuard.Against(
                            availability == null,
                            "Therapist is not available on this day.");

                        if (availability == null)
                        {
                            throw new NotFoundException(
                                "Therapist availability was not found.");
                        }

                        var startTime =
                            request.StartUtc
                                .TimeOfDay;

                        var endTime =
                            request.EndUtc
                                .TimeOfDay;

                        BusinessRuleGuard.Against(
                            startTime <
                                availability.StartTime ||
                            endTime >
                                availability.EndTime,
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
        int therapistId,
        CancellationToken cancellationToken =
            default)
    {
        if (therapistId <= 0)
        {
            throw new ArgumentException(
                "Therapist identifier is invalid.",
                nameof(therapistId));
        }

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
            $"MindBloom.AppointmentBooking.Therapist.{therapistId}";

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
                AppointmentSlotConflictMessage);
        }
    }

    private async Task
    AutoCompleteAppointmentsAsync()
    {
        var appointments =
            await _context.Appointments
                .Include(x =>
                    x.Client)
                    .ThenInclude(x =>
                        x.User)
                .Include(x =>
                    x.Therapist)
                    .ThenInclude(x =>
                        x.User)
                .Where(x =>
                    x.EndUtc <
                        DateTime.UtcNow &&
                    x.Status !=
                        AppointmentStatus.Completed &&
                    x.Status !=
                        AppointmentStatus.Cancelled &&
                    x.Status !=
                        AppointmentStatus.Rejected)
                .ToListAsync();

        if (appointments.Count == 0)
        {
            return;
        }

        foreach (var appointment
                 in appointments)
        {
            appointment.Status =
                AppointmentStatus.Completed;
        }

        await _context.SaveChangesAsync();

        foreach (var appointment
                 in appointments)
        {
            await _membershipService
                .FinalizeAppointmentUsageAsync(
                    appointment.Id,
                    "Membership session consumed after automatic appointment completion.");

            var correlationId =
                Guid.NewGuid();

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
                        appointment.Therapist.UserId,

                    StartUtc =
                        appointment.StartUtc,

                    EndUtc =
                        appointment.EndUtc,

                    CompletedByUserId =
                        null,

                    AppointmentType =
                        appointment.Type.ToString(),

                    Price =
                        appointment.Price
                };

            await _integrationEventPublisher
                .PublishAsync(
                    appointmentCompletedEvent,
                    IntegrationEventRoutingKeys
                        .AppointmentCompleted);
        }
    }

    public async Task<List<AppointmentResponseDto>>
     GetMyAppointmentsAsync(int userId)
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

        return await _context.Appointments
            .AsNoTracking()
            .Include(x => x.Therapist)
                .ThenInclude(x => x.User)
            .Where(x =>
                x.ClientId == client.Id)
            .OrderBy(x =>
                x.StartUtc)
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

                    Notes=x.Notes,

                    Location =
                        x.Location,

                    PaymentId =
    x.Payment != null
        ? x.Payment.Id
        : null
                })
            .ToListAsync();
    }



    public async Task<List<AppointmentResponseDto>>
    GetTherapistAppointmentsAsync(int therapistUserId)
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

        return await _context.Appointments
            .AsNoTracking()
            .Include(x => x.Client)
            .ThenInclude(x => x.User)
            .Where(x => x.TherapistId == therapist.Id)
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
    }

    public async Task UpdateStatusAsync(
     int therapistUserId,
     UpdateAppointmentStatusDto request)
    {
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

        if (!IsValidStatusTransition(
          appointment.Status,
          request.Status))
        {
            throw new BusinessException(
                $"Status transition from {appointment.Status} to {request.Status} is not allowed.");
        }

        if (request.Status ==
            AppointmentStatus.Rejected)
        {
            await _membershipService
                .HandleAppointmentCancellationAsync(
                    appointment.Id,
                    "Appointment rejected by therapist.",
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
                    "Appointment rejected by therapist.",

                AppointmentStatus.Completed =>
                    "Appointment completed by therapist.",

                _ =>
                    "Appointment status changed by therapist."
            },

        ChangedAtUtc =
            DateTime.UtcNow
    });

        await _context.SaveChangesAsync();

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

                    await _integrationEventPublisher
                        .PublishAsync(
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
                                "Appointment rejected by therapist."
                        };

                    await _integrationEventPublisher
                        .PublishAsync(
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

                    await _integrationEventPublisher
                        .PublishAsync(
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

                    await _integrationEventPublisher
                        .PublishAsync(
                            appointmentCompletedEvent,
                            IntegrationEventRoutingKeys
                                .AppointmentCompleted);

                    break;
                }
        }
    }

    public async Task CancelAppointmentAsync(
    int clientUserId,
    int appointmentId,
    CancelAppointmentDto request)
    {
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
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new NotFoundException("Therapist not found.");
        }

        var totalAppointments =
     await _context.Appointments
         .CountAsync(x =>
             x.TherapistId == therapist.Id);

        var completedAppointments =
            await _context.Appointments
                .CountAsync(x =>
                    x.TherapistId == therapist.Id
                    && x.Status ==
                        AppointmentStatus.Accepted
                    && x.EndUtc < DateTime.UtcNow);

        var cancelledAppointments =
            await _context.Appointments
                .CountAsync(x =>
                    x.TherapistId == therapist.Id
                    && x.Status ==
                        AppointmentStatus.Cancelled);

        decimal totalEarnings =
            completedAppointments * 50;

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
            throw new Exception(
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
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointments =
            await _context.Appointments
            .AsNoTracking()
                .Include(x => x.Therapist)
                .Where(x =>
                    x.ClientId == client.Id)
                .ToListAsync();

        return new ClientDashboardDto
        {
            TotalAppointments =
                appointments.Count,

            CompletedAppointments =
                appointments.Count(x =>
                    x.Status
                    == AppointmentStatus.Completed),

            PendingAppointments =
                appointments.Count(x =>
                    x.Status
                    == AppointmentStatus.Pending),

            CancelledAppointments =
                appointments.Count(x =>
                    x.Status
                    == AppointmentStatus.Cancelled
                    || x.Status
                    == AppointmentStatus.Rejected),

            TotalTherapistsVisited =
                appointments
                    .Select(x => x.TherapistId)
                    .Distinct()
                    .Count(),

            TotalSpent =
                appointments
                    .Where(x =>
                        x.Status
                        == AppointmentStatus.Completed)
                    .Sum(x =>
                        x.Therapist.HourlyRate),

            LastAppointmentDate =
                appointments
                    .Where(x =>
                        x.EndUtc
                        < DateTime.UtcNow)
                    .OrderByDescending(x =>
                        x.EndUtc)
                    .Select(x =>
                        (DateTime?)x.EndUtc)
                    .FirstOrDefault(),

            NextAppointmentDate =
                appointments
                    .Where(x =>
                        x.StartUtc
                        > DateTime.UtcNow)
                    .OrderBy(x =>
                        x.StartUtc)
                    .Select(x =>
                        (DateTime?)x.StartUtc)
                    .FirstOrDefault()
        };
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
            throw new Exception(
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
                .AnyAsync(x =>
                    x.Id == therapistId &&
                    x.VerificationStatus ==
                        TherapistVerificationStatus.Approved);

        if (!therapistExists)
        {
            throw new NotFoundException(
                "Therapist not found or is not available.");
        }

        var dateUtc = DateTime.SpecifyKind(
            date.Date,
            DateTimeKind.Utc);

        var nextDateUtc =
            dateUtc.AddDays(1);

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
                    StartUtc = x.StartUtc,
                    EndUtc = x.EndUtc
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


