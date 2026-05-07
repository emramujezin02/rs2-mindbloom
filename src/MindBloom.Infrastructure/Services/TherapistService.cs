using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class TherapistService : ITherapistService
{
    private readonly ApplicationDbContext _context;

    public TherapistService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<TherapistResponseDto> CreateAsync(
        int userId,
        CreateTherapistDto request)
    {
        var user =
            await _context.Users
                .FirstOrDefaultAsync(x => x.Id == userId);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var therapist = new Therapist
        {
            UserId = userId,
            Specialization = request.Specialization,
            Biography = request.Biography,
            HourlyRate = request.HourlyRate,
            ExperienceYears = request.ExperienceYears
        };

        _context.Therapists.Add(therapist);

        await _context.SaveChangesAsync();

        return new TherapistResponseDto
        {
            Id = therapist.Id,
            UserId = therapist.UserId,
            FullName = $"{user.FirstName} {user.LastName}",
            Email = user.Email!,
            Specialization = therapist.Specialization,
            Biography = therapist.Biography,
            HourlyRate = therapist.HourlyRate,
            ExperienceYears = therapist.ExperienceYears
        };
    }

    public async Task<List<TherapistResponseDto>>
        GetAllAsync()
    {
        return await _context.Therapists
            .Include(x => x.User)
            .Select(x => new TherapistResponseDto
            {
                Id = x.Id,
                UserId = x.UserId,
                FullName =
                    x.User.FirstName + " " + x.User.LastName,
                Email = x.User.Email!,
                Specialization = x.Specialization,
                Biography = x.Biography,
                HourlyRate = x.HourlyRate,
                ExperienceYears = x.ExperienceYears
            })
            .ToListAsync();
    }

    public async Task AddAvailabilityAsync(
        int therapistId,
        CreateAvailabilityDto request)
    {
        var availability =
            new TherapistAvailability
            {
                TherapistId = therapistId,
                DayOfWeek = request.DayOfWeek,
                StartTime = request.StartTime,
                EndTime = request.EndTime
            };

        _context.TherapistAvailabilities.Add(availability);

        await _context.SaveChangesAsync();
    }

    public async Task<List<AvailabilityResponseDto>>
        GetAvailabilitiesAsync(int therapistId)
    {
        return await _context.TherapistAvailabilities
            .Where(x => x.TherapistId == therapistId)
            .Select(x => new AvailabilityResponseDto
            {
                Id = x.Id,
                DayOfWeek = x.DayOfWeek,
                StartTime = x.StartTime,
                EndTime = x.EndTime
            })
            .ToListAsync();
    }
}