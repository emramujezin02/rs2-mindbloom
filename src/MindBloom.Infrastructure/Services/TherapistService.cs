using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Domain.Enums;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;


namespace MindBloom.Infrastructure.Services;

public class TherapistService : ITherapistService
{
    private readonly ApplicationDbContext _context;
    private readonly IWebHostEnvironment _environment;

    public TherapistService(ApplicationDbContext context, IWebHostEnvironment environment)
    {
        _context = context;
        _environment = environment;

    }
    public async Task<TherapistResponseDto> CreateAsync(int userId, CreateTherapistDto request)
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

    public async Task<TherapistDetailsDto>
    GetByIdAsync(int therapistId)
    {
        var therapist =
            await _context.Therapists
                .Include(x => x.User)
                .Include(x => x.Reviews)
                .Include(x => x.Availabilities)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        return new TherapistDetailsDto
        {
            Id = therapist.Id,

            FullName =
                therapist.User.FirstName
                + " "
                + therapist.User.LastName,

            Email = therapist.User.Email!,

            Biography = therapist.Biography,

            Specialization =
                therapist.Specialization,

            HourlyRate =
                therapist.HourlyRate,

            ExperienceYears =
                therapist.ExperienceYears,

            AverageRating =
                therapist.Reviews.Any()
                    ? Math.Round(
                        therapist.Reviews
                            .Average(x => x.Rating),
                        1)
                    : 0,

            TotalReviews =
                therapist.Reviews.Count,

            Availabilities =
                therapist.Availabilities
                    .Select(x =>
                        new AvailabilityResponseDto
                        {
                            Id = x.Id,

                            DayOfWeek =
                                x.DayOfWeek,

                            StartTime =
                                x.StartTime,

                            EndTime =
                                x.EndTime
                        })
                    .ToList()
        };
    }

    public async Task DeleteAvailabilityAsync(
    int therapistUserId,
    int availabilityId)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new Exception("Therapist not found.");
        }

        var availability =
            await _context.TherapistAvailabilities
                .FirstOrDefaultAsync(x =>
                    x.Id == availabilityId
                    && x.TherapistId == therapist.Id);

        if (availability == null)
        {
            throw new Exception(
                "Availability not found.");
        }

        _context.TherapistAvailabilities
            .Remove(availability);

        await _context.SaveChangesAsync();
    }

    public async Task<TherapistDashboardDto>
    GetDashboardAsync(int therapistUserId)
    {
        var therapist =
            await _context.Therapists
                .Include(x => x.Reviews)
                .Include(x => x.Appointments)
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId);

        if (therapist == null)
        {
            throw new Exception("Therapist not found.");
        }

        var completedAppointments =
            therapist.Appointments
                .Where(x =>
                    x.Status == AppointmentStatus.Completed)
                .ToList();

        return new TherapistDashboardDto
        {
            TotalAppointments =
                therapist.Appointments.Count,

            CompletedAppointments =
                completedAppointments.Count,

            PendingAppointments =
                therapist.Appointments.Count(x =>
                    x.Status == AppointmentStatus.Pending),

            AverageRating =
                therapist.Reviews.Any()
                    ? Math.Round(
                        therapist.Reviews
                            .Average(x => x.Rating),
                        1)
                    : 0,

            TotalReviews =
                therapist.Reviews.Count,

            TotalEarnings =
                completedAppointments.Sum(x => 50)
        };
    }

    public async Task AddUnavailableDateAsync(
    int therapistUserId,
    CreateUnavailableDateDto request)
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

        if (request.StartUtc >= request.EndUtc)
        {
            throw new Exception(
                "Invalid date range.");
        }

        var hasOverlap =
            await _context
                .TherapistUnavailableDates
                .AnyAsync(x =>
                    x.TherapistId == therapist.Id
                    && request.StartUtc < x.EndUtc
                    && request.EndUtc > x.StartUtc);

        if (hasOverlap)
        {
            throw new Exception(
                "Unavailable date overlaps with existing one.");
        }

        var unavailableDate =
            new TherapistUnavailableDate
            {
                TherapistId = therapist.Id,
                StartUtc = request.StartUtc,
                EndUtc = request.EndUtc,
                Reason = request.Reason
            };

        _context
            .TherapistUnavailableDates
            .Add(unavailableDate);

        await _context.SaveChangesAsync();
    }

    public async Task<
    List<UnavailableDateResponseDto>>
    GetUnavailableDatesAsync(
        int therapistId)
    {
        return await _context
            .TherapistUnavailableDates
            .Where(x =>
                x.TherapistId == therapistId)
            .OrderBy(x => x.StartUtc)
            .Select(x =>
                new UnavailableDateResponseDto
                {
                    Id = x.Id,
                    StartUtc = x.StartUtc,
                    EndUtc = x.EndUtc,
                    Reason = x.Reason
                })
            .ToListAsync();
    }

    public async Task DeleteUnavailableDateAsync(
    int therapistUserId,
    int unavailableDateId)
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

        var unavailableDate =
            await _context
                .TherapistUnavailableDates
                .FirstOrDefaultAsync(x =>
                    x.Id == unavailableDateId
                    && x.TherapistId == therapist.Id);

        if (unavailableDate == null)
        {
            throw new Exception(
                "Unavailable date not found.");
        }

        _context
            .TherapistUnavailableDates
            .Remove(unavailableDate);

        await _context.SaveChangesAsync();
    }

    public async Task UploadDocumentAsync(
    int therapistUserId,
    IFormFile file)
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

        if (file == null || file.Length == 0)
        {
            throw new Exception(
                "Invalid file.");
        }

        var allowedTypes =
            new[]
            {
            "image/jpeg",
            "image/png",
            "application/pdf"
            };

        if (!allowedTypes.Contains(
            file.ContentType))
        {
            throw new Exception(
                "Only JPG, PNG and PDF files are allowed.");
        }

        var webRootPath =
    _environment.WebRootPath
    ?? Path.Combine(
        Directory.GetCurrentDirectory(),
        "wwwroot");

        var uploadsFolder =
            Path.Combine(
                _environment.WebRootPath?? Path.Combine(webRootPath,"uploads","therapist"),
                "uploads",
                "therapists");

        if (!Directory.Exists(
            uploadsFolder))
        {
            Directory.CreateDirectory(
                uploadsFolder);
        }

        var uniqueFileName =
            $"{Guid.NewGuid()}_{file.FileName}";

        var filePath =
            Path.Combine(
                uploadsFolder,
                uniqueFileName);

        using var stream =
            new FileStream(
                filePath,
                FileMode.Create);

        await file.CopyToAsync(stream);

        var document =
            new TherapistDocument
            {
                TherapistId = therapist.Id,

                FileName = file.FileName,

                FilePath =
                    $"/uploads/therapists/{uniqueFileName}",

                ContentType =
                    file.ContentType,

                IsApproved = false
            };

        _context.TherapistDocuments
            .Add(document);

        await _context.SaveChangesAsync();
    }

    public async Task<
    List<TherapistDocumentResponseDto>>
    GetDocumentsAsync(
        int therapistId)
    {
        return await _context
            .TherapistDocuments
            .Where(x =>
                x.TherapistId == therapistId)
            .Select(x =>
                new TherapistDocumentResponseDto
                {
                    Id = x.Id,

                    FileName =
                        x.FileName,

                    FilePath =
                        x.FilePath,

                    ContentType =
                        x.ContentType,

                    IsApproved =
                        x.IsApproved
                })
            .ToListAsync();
    }

    public async Task DeleteDocumentAsync(
    int therapistUserId,
    int documentId)
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

        var document =
            await _context
                .TherapistDocuments
                .FirstOrDefaultAsync(x =>
                    x.Id == documentId
                    && x.TherapistId
                        == therapist.Id);

        if (document == null)
        {
            throw new Exception(
                "Document not found.");
        }

        var physicalPath =
            Path.Combine(
                _environment.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(),"wwwroot"),
                document.FilePath.TrimStart('/')
                    .Replace("/",
                        Path.DirectorySeparatorChar.ToString()));

        if (File.Exists(physicalPath))
        {
            File.Delete(physicalPath);
        }

        _context.TherapistDocuments
            .Remove(document);

        await _context.SaveChangesAsync();
    }
}