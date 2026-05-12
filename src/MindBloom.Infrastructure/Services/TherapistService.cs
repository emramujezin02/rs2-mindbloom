using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
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

    public async Task<PagedResponse<TherapistResponseDto>>
    SearchAsync(SearchTherapistsDto request)
    {
        var query =
            _context.Therapists
                .Include(x => x.User)
                .Include(x => x.Reviews)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Name))
        {
            query = query.Where(x =>
                (x.User.FirstName + " "
                 + x.User.LastName)
                .ToLower()
                .Contains(request.Name.ToLower()));
        }

        if (!string.IsNullOrWhiteSpace(
            request.Specialization))
        {
            query = query.Where(x =>
                x.Specialization.ToLower()
                .Contains(
                    request.Specialization.ToLower()));
        }

        query = request.SortBy?.ToLower() switch
        {
            "rating" =>
                query.OrderByDescending(x =>
                    x.Reviews.Any()
                        ? x.Reviews.Average(r => r.Rating)
                        : 0),

            "price" =>
                query.OrderBy(x => x.HourlyRate),

            "experience" =>
                query.OrderByDescending(
                    x => x.ExperienceYears),

            _ =>
                query.OrderBy(x => x.Id)
        };

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .Skip(
                    (request.PageNumber - 1)
                    * request.PageSize)

                .Take(request.PageSize)

                .Select(x => new TherapistResponseDto
                {
                    Id = x.Id,

                    FullName =
                        x.User.FirstName
                        + " "
                        + x.User.LastName,

                    Email = x.User.Email!,

                    Specialization =
                        x.Specialization,

                    Biography = x.Biography,

                    HourlyRate =
                        x.HourlyRate,

                    ExperienceYears =
                        x.ExperienceYears,

                    AverageRating =
                        x.Reviews.Any()
                            ? x.Reviews.Average(
                                r => r.Rating)
                            : 0
                })
                .ToListAsync();

        return new PagedResponse<TherapistResponseDto>
        {
            Items = items,

            PageNumber = request.PageNumber,

            PageSize = request.PageSize,

            TotalCount = totalCount,

            TotalPages =
                (int)Math.Ceiling(
                    totalCount
                    / (double)request.PageSize)
        };
    }

    public async Task<List<TherapistResponseDto>>
    FilterAsync(
        TherapistFilterDto filter)
    {
        var query =
            _context.Therapists
                .Include(x => x.User)
                .Include(x => x.Reviews)
                .AsQueryable();


        if (!string.IsNullOrWhiteSpace(
            filter.Specialization))
        {
            var specialization =
                filter.Specialization.ToLower();

            query = query.Where(x =>
                x.Specialization
                    .ToLower()
                    .Contains(specialization));
        }

        if (filter.MinPrice.HasValue)
        {
            query = query.Where(x =>
                x.HourlyRate >= filter.MinPrice.Value);
        }

        if (filter.MaxPrice.HasValue)
        {
            query = query.Where(x =>
                x.HourlyRate <= filter.MaxPrice.Value);
        }

        var therapists =
            await query
                .Select(x => new TherapistResponseDto
                {
                    Id = x.Id,

                    FullName =
                        x.User.FirstName
                        + " "
                        + x.User.LastName,

                    Specialization =
                        x.Specialization,

                    Biography =
                        x.Biography,

                    HourlyRate =
                        x.HourlyRate,

                    ExperienceYears =
                        x.ExperienceYears,

                    AverageRating =
                        x.Reviews.Any()
                            ? Math.Round(
                                x.Reviews
                                    .Average(r => r.Rating),
                                1)
                            : 0,

                    TotalReviews =
                        x.Reviews.Count
                })
                .ToListAsync();

        if (filter.SortByRating)
        {
            therapists = therapists
                .OrderByDescending(
                    x => x.AverageRating)
                .ToList();
        }

        return therapists;
    }

    public async Task UpdateProfileAsync(
    int therapistUserId,
    UpdateTherapistProfileDto request)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new Exception("Therapist not found.");
        }

        therapist.Biography = request.Biography;

        therapist.Specialization = request.Specialization;

        therapist.ExperienceYears = request.ExperienceYears;

        Console.WriteLine(therapist.Biography);
        Console.WriteLine(therapist.Specialization);
        Console.WriteLine(therapist.ExperienceYears);

        await _context.SaveChangesAsync();
    }
}