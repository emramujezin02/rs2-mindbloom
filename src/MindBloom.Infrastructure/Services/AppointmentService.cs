using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Domain.Enums;

namespace MindBloom.Infrastructure.Services;

public class AppointmentService : IAppointmentService
{
    private readonly ApplicationDbContext _context;

    public AppointmentService(ApplicationDbContext context)
    {
        _context = context;
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

        var appointment = new Appointment
        {
            TherapistId = request.TherapistId,
            StartUtc = request.StartUtc,
            ClientId = client.Id,
            EndUtc = request.EndUtc,
            Status = AppointmentStatus.Pending
        };

        _context.Appointments.Add(appointment);

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

    public async Task<List<AppointmentResponseDto>>
        GetMyAppointmentsAsync(int userId)
    {
        return await _context.Appointments
            .Include(x => x.Therapist)
            .ThenInclude(x => x.User)
            .Where(x => x.ClientId == userId)
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
                Status = x.Status.ToString()
            })
            .ToListAsync();
    }
}