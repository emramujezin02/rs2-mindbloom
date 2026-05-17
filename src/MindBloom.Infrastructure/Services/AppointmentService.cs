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
namespace MindBloom.Infrastructure.Services;

public class AppointmentService : IAppointmentService
{
    private readonly ApplicationDbContext _context;
    private readonly INotificationSender _notificationSender;
    public AppointmentService(ApplicationDbContext context, INotificationSender notificationSender)
    {
        _context = context;
        _notificationSender = notificationSender;
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
            throw new Exception("Therapist not found.");
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
                    x.TherapistId == request.TherapistId
                    && request.StartUtc < x.EndUtc
                    && request.EndUtc > x.StartUtc);

        if (overlappingAppointment)
        {
            throw new Exception(
                "Selected appointment time is already booked.");
        }

        var client = await _context.Clients
    .FirstOrDefaultAsync(x => x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception("Client profile not found.");
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


        await _notificationSender.SendToUserAsync(
    therapist.UserId,
    "New Appointment",
    "You have received a new appointment request.");


        var notification = new Notification
        {
            UserId = therapist.UserId,
            Title = "New Appointment",
            Message =
                "You have received a new appointment request.",
            IsRead = false
        };

        _context.Notifications.Add(notification);

        await _context.SaveChangesAsync();

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

    private async Task AutoCompleteAppointmentsAsync()
    {
        var appointments =
            await _context.Appointments
                .Where(x =>
                    x.EndUtc < DateTime.Now
                    && x.Status != AppointmentStatus.Completed
                    && x.Status != AppointmentStatus.Cancelled
                    && x.Status != AppointmentStatus.Rejected)
                .ToListAsync();

        foreach (var appointment in appointments)
        {
            appointment.Status =
                AppointmentStatus.Completed;
        }

        await _context.SaveChangesAsync();
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
            throw new Exception("Client profile not found.");
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
            throw new Exception("Therapist not found.");
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
                .FirstOrDefaultAsync(
                    x => x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new Exception("Therapist not found.");
        }

        var appointment =
    await _context.Appointments
        .Include(x => x.Client)
        .FirstOrDefaultAsync(x =>
            x.Id == request.AppointmentId
            && x.TherapistId == therapist.Id);

        if (appointment == null)
        {
            throw new Exception("Appointment not found.");
        }

        appointment.Status = request.Status;

        var client =
    await _context.Clients
        .Include(x => x.User)
        .FirstOrDefaultAsync(x =>
            x.Id == appointment.ClientId);

        if (client != null)
        {
            var notification = new Notification
            {
                UserId = client.UserId,
                Title = "Appointment Updated",
                Message =
                    $"Your appointment status is now {request.Status}.",
                IsRead = false
            };

            _context.Notifications.Add(notification);
        }

        await _context.SaveChangesAsync();

        await _notificationSender.SendToUserAsync(
    appointment.Client.UserId,
    "Appointment Updated",
    $"Your appointment status is now {request.Status}.");
    }

    public async Task CancelAppointmentAsync(
    int clientUserId,
    int appointmentId,
    CancelAppointmentDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception("Client not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x => x.Therapist)
                .ThenInclude(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId
                    && x.ClientId == client.Id);

        if (appointment == null)
        {
            throw new Exception("Appointment not found.");
        }

        if (appointment.Status == AppointmentStatus.Cancelled)
        {
            throw new Exception(
                "Appointment is already cancelled.");
        }

        appointment.Status = AppointmentStatus.Cancelled;

        var notification = new Notification
        {
            UserId = appointment.Therapist.UserId,
            Title = "Appointment Cancelled",
            Message =
                $"A client cancelled the appointment. Reason: {request.Reason}",
            IsRead = false
        };

        _context.Notifications.Add(notification);

        await _context.SaveChangesAsync();

        await _notificationSender.SendToUserAsync(
            appointment.Therapist.UserId,
            "Appointment Cancelled",
            $"A client cancelled the appointment. Reason: {request.Reason}");
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
            throw new Exception("Therapist not found.");
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
            throw new Exception(
                "Therapist not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId
                    && x.TherapistId == therapist.Id);

        if (appointment == null)
        {
            throw new Exception(
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
            throw new Exception(
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
            throw new Exception(
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
            throw new Exception(
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
}


