using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Domain.Enums;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Common.Exceptions;

namespace MindBloom.Infrastructure.Services;

public class AppointmentService : IAppointmentService
{
    private readonly ApplicationDbContext _context;

    private readonly IBusinessNotificationService _businessNotificationService;

    private readonly IPaymentService _paymentService;

    private readonly IMembershipService _membershipService;

    public AppointmentService(
        ApplicationDbContext context,
        IBusinessNotificationService businessNotificationService,
        IPaymentService paymentService,
        IMembershipService membershipService)
    {
        _context = context;

        _businessNotificationService = businessNotificationService;

        _paymentService = paymentService;

        _membershipService = membershipService;
    }

    public async Task<AppointmentResponseDto>
        CreateAsync(
            int clientUserId,
            CreateAppointmentDto request)
    {
        var therapist =
            await _context.Therapists
                .Include(x => x.User)
                .FirstOrDefaultAsync(
                    x => x.Id == request.TherapistId);

        if (request.StartUtc < DateTime.Now)
        {
            throw new Exception(
                "You cannot book appointments in the past.");
        }

        if (therapist == null)
        {
            throw new NotFoundException("Therapist not found.");
        }

        var dayOfWeek =
            request.StartUtc.DayOfWeek;

        var availability =
            await _context.TherapistAvailabilities
                .FirstOrDefaultAsync(x =>
                    x.TherapistId == request.TherapistId
                    && x.DayOfWeek == dayOfWeek);

        if (availability == null)
        {
            throw new Exception(
                "Therapist is not available on this day.");
        }

        var startTime =
            request.StartUtc.TimeOfDay;

        var endTime =
            request.EndUtc.TimeOfDay;

        if (request.StartUtc >= request.EndUtc)
        {
            throw new Exception(
                "Appointment start time must be before end time.");
        }

        var appointmentDuration =
            request.EndUtc - request.StartUtc;

        if (appointmentDuration != TimeSpan.FromHours(1))
        {
            throw new Exception(
                "Appointment must last exactly one hour.");
        }

        if (startTime < availability.StartTime
            || endTime > availability.EndTime)
        {
            throw new Exception(
                "Appointment is outside working hours.");
        }

        var unavailableDate =
    await _context
        .TherapistUnavailableDates
        .AnyAsync(x =>
            x.TherapistId
                == request.TherapistId
            && request.StartUtc < x.EndUtc
            && request.EndUtc > x.StartUtc);

        if (unavailableDate)
        {
            throw new Exception(
                "Therapist is unavailable during this time.");
        }

        var overlappingAppointment =
    await _context.Appointments
        .AnyAsync(x =>
            x.TherapistId ==
                request.TherapistId &&
            request.StartUtc < x.EndUtc &&
            request.EndUtc > x.StartUtc &&
            (
                x.Status ==
                    AppointmentStatus.Pending ||
                x.Status ==
                    AppointmentStatus.Accepted
            ));

        if (overlappingAppointment)
        {
            throw new BusinessException(
                "Selected appointment time is already booked.");
        }

        var client = await _context.Clients
    .FirstOrDefaultAsync(x => x.UserId == clientUserId);

        if (client == null)
        {
            throw new NotFoundException("Client profile not found.");
        }

        if (request.Type
    == AppointmentType.Online
    && string.IsNullOrWhiteSpace(
        request.MeetingLink))
        {
            throw new Exception(
                "Meeting link is required for online appointments.");
        }

        if (request.Type
            == AppointmentType.InPerson
            && string.IsNullOrWhiteSpace(
                request.Location))
        {
            throw new Exception(
                "Location is required for in-person appointments.");
        }

        var appointment = new Appointment
        {
            TherapistId = request.TherapistId,
            StartUtc = request.StartUtc,
            ClientId = client.Id,
            EndUtc = request.EndUtc,
            Status = AppointmentStatus.Pending,
            Type = request.Type,

            MeetingLink = request.MeetingLink,

            Location = request.Location,
        };

        _context.Appointments.Add(appointment);

        await _context.SaveChangesAsync();

        _context.AppointmentStatusAudits.Add(
    new AppointmentStatusAudit
    {
        AppointmentId =
            appointment.Id,

        ChangedByUserId =
            clientUserId,

        PreviousStatus =
            null,

        NewStatus =
            AppointmentStatus.Pending,

        Action =
            "Created",

        Reason =
            "Appointment created by client.",

        ChangedAtUtc =
            DateTime.UtcNow
    });

        await _context.SaveChangesAsync();

        await _businessNotificationService
            .PublishAsync(
                therapist.UserId,
                "New appointment request",
                "You have received a new appointment request.",
                appointment.Id);

        return new AppointmentResponseDto
        {
            Id = appointment.Id,
            TherapistId = therapist.Id,
            TherapistName =
                therapist.User.FirstName + " "
                + therapist.User.LastName,
            StartUtc = appointment.StartUtc,
            EndUtc = appointment.EndUtc,
            Status = appointment.Status.ToString()
        };
    }

    private async Task
        AutoCompleteAppointmentsAsync()
    {
        var appointments =
            await _context.Appointments
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
            .Include(x => x.Therapist)
            .ThenInclude(x => x.User)
            .Where(x => x.ClientId == client.Id)
            .Select(x => new AppointmentResponseDto
            {
                Id = x.Id,
                TherapistId = x.TherapistId,
                TherapistName =
                    x.Therapist.User.FirstName
                    + " "
                    + x.Therapist.User.LastName,
                StartUtc = x.StartUtc,
                EndUtc = x.EndUtc,
                Status = x.Status.ToString(),
                Type = x.Type.ToString(),

                MeetingLink = x.MeetingLink,

                Location = x.Location,
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

                StartUtc = x.StartUtc,

                EndUtc = x.EndUtc,

                Status = x.Status.ToString()
            })
            .ToListAsync();
    }

    public async Task UpdateStatusAsync(
     int therapistUserId,
     UpdateAppointmentStatusDto request)
    {
        var therapist =
            await _context.Therapists
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

        if (appointment.Status ==
                AppointmentStatus.Cancelled ||
            appointment.Status ==
                AppointmentStatus.Rejected ||
            appointment.Status ==
                AppointmentStatus.Completed)
        {
            if (appointment.Status ==
                request.Status)
            {
                return;
            }

            throw new Exception(
                "The status of a finished appointment cannot be changed.");
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

        var notificationTitle =
            request.Status switch
            {
                AppointmentStatus.Accepted =>
                    "Appointment accepted",

                AppointmentStatus.Rejected =>
                    "Appointment rejected",

                AppointmentStatus.Completed =>
                    "Appointment completed",

                _ =>
                    "Appointment updated"
            };

        var notificationMessage =
            request.Status switch
            {
                AppointmentStatus.Accepted =>
                    "Your appointment request has been accepted by the therapist.",

                AppointmentStatus.Rejected =>
                    "Your appointment request has been rejected by the therapist.",

                AppointmentStatus.Completed =>
                    "Your appointment has been marked as completed.",

                _ =>
                    $"Your appointment status is now {request.Status}."
            };

        await _businessNotificationService
            .PublishAsync(
                appointment.Client.UserId,
                notificationTitle,
                notificationMessage,
                appointment.Id);
    }

    public async Task CancelAppointmentAsync(
    int clientUserId,
    int appointmentId,
    CancelAppointmentDto request)
    {
        var reason =
            request.Reason?.Trim() ??
            string.Empty;

        if (string.IsNullOrWhiteSpace(
                reason))
        {
            throw new Exception(
                "Cancellation reason is required.");
        }

        if (reason.Length < 5)
        {
            throw new Exception(
                "Cancellation reason must contain at least 5 characters.");
        }

        if (reason.Length > 500)
        {
            throw new Exception(
                "Cancellation reason may contain at most 500 characters.");
        }

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
            throw new Exception(
                "A completed appointment cannot be cancelled.");
        }

        if (appointment.Status ==
            AppointmentStatus.Rejected)
        {
            throw new Exception(
                "A rejected appointment cannot be cancelled.");
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

        await _businessNotificationService
            .PublishAsync(
                appointment.Therapist.UserId,
                "Appointment cancelled",
                "A client cancelled the appointment. "
                + $"Reason: {reason}",
                appointment.Id);
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

        var appointments =
            await _context.Appointments
                .Where(x =>
                    x.TherapistId == therapist.Id)
                .ToListAsync();

        var completedAppointments =
            appointments.Count(x =>
                x.Status == AppointmentStatus.Accepted
                && x.EndUtc < DateTime.Now);

        var cancelledAppointments =
            appointments.Count(x =>
                x.Status == AppointmentStatus.Cancelled);

        decimal totalEarnings =
            completedAppointments * 50;

        return new TherapistStatsDto
        {
            TotalAppointments = appointments.Count,

            CompletedAppointments =
                completedAppointments,

            CancelledAppointments =
                cancelledAppointments,

            TotalEarnings = totalEarnings
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

        return await _context.AppointmentNotes
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
}


