using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Domain.Enums;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using System.Threading;
using MindBloom.Application.Common.Pagination;

namespace MindBloom.Infrastructure.Services;

public class TherapistService : ITherapistService
{
    private readonly ApplicationDbContext _context;
    private readonly IWebHostEnvironment _environment;

    private const long MaximumDocumentSize =
    10 * 1024 * 1024;

    private static readonly HashSet<string>
        AllowedDocumentExtensions =
        new(StringComparer.OrdinalIgnoreCase)
        {
        ".jpg",
        ".jpeg",
        ".png",
        ".pdf"
        };

    private static readonly HashSet<string>
        AllowedDocumentMimeTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
        "image/jpeg",
        "image/png",
        "application/pdf"
        };

    private readonly IGeocodingService _geocodingService;

    public TherapistService(ApplicationDbContext context, IWebHostEnvironment environment, IGeocodingService geocodingService)
    {
        _context = context;
        _environment = environment;
        _geocodingService = geocodingService;

    }
    public async Task<TherapistResponseDto> CreateAsync(int userId, CreateTherapistDto request)
    {
        var user =
            await _context.Users
                .FirstOrDefaultAsync(x => x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var therapist = new Therapist
        {
            UserId = userId,
            Specialization = request.Specialization,
            Biography = request.Biography,
            HourlyRate = request.HourlyRate,
            ExperienceYears = request.ExperienceYears,
            VerificationStatus = TherapistVerificationStatus.Pending,
            Country = request.Country.Trim(),
            City = request.City.Trim(),
            Address = request.Address.Trim(),
            OffersOnline = request.OffersOnline,
            OffersInPerson = request.OffersInPerson,
        };

        await UpdateCoordinatesAsync(
            therapist,
            CancellationToken.None);

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
            ExperienceYears = therapist.ExperienceYears,
            ProfileImageUrl = therapist.ProfileImagePath,
            Country = therapist.Country,
            City = therapist.City,
            Address = therapist.Address,
            OffersOnline = therapist.OffersOnline,
            OffersInPerson = therapist.OffersInPerson,
            Latitude = therapist.Latitude,
            Longitude = therapist.Longitude,
        };
    }

    public async Task<List<TherapistResponseDto>>
        GetAllAsync()
    {
        return await _context.Therapists
            .AsNoTracking()
            .Include(x => x.User)
            .Include(x => x.Reviews)
                    .Where(x =>
    !x.IsDeleted &&
    x.VerificationStatus ==
        TherapistVerificationStatus.Approved)
            .Select(x => new TherapistResponseDto
            {
                Id = x.Id,
                UserId = x.UserId,
                FullName = x.User.FirstName + " " + x.User.LastName,
                Email = x.User.Email!,
                Specialization = x.Specialization,
                Biography = x.Biography,
                HourlyRate = x.HourlyRate,
                ExperienceYears = x.ExperienceYears,
                AverageRating = x.Reviews.Any() ? Math.Round(x.Reviews.Average(r => r.Rating), 1): 0,
                TotalReviews = x.Reviews.Count,
                VerificationStatus = x.VerificationStatus.ToString(),
                VerificationNotes = x.VerificationNotes,
                ProfileImageUrl = x.User.ProfileImageUrl ?? x.ProfileImagePath,
                Country = x.Country,
                City = x.City,
                Address = x.Address,
                OffersOnline = x.OffersOnline,
                OffersInPerson = x.OffersInPerson,
                Latitude = x.Latitude,
                Longitude = x.Longitude,
                TherapyApproaches = x.TherapyApproaches
    .Where(ta =>
        !ta.IsDeleted &&
        !ta.TherapyApproach.IsDeleted &&
        ta.TherapyApproach.IsActive)
    .OrderBy(ta => ta.TherapyApproach.Name)
    .Select(ta => ta.TherapyApproach.Name)
    .ToList(),
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
        var pagination =
            PaginationHelper.Normalize(
                request.PageNumber,
                request.PageSize);

        if (request.MinPrice.HasValue &&
            request.MinPrice.Value < 0)
        {
            throw new BadRequestException(
                "Minimum price cannot be negative.");
        }

        if (request.MaxPrice.HasValue &&
            request.MaxPrice.Value < 0)
        {
            throw new BadRequestException(
                "Maximum price cannot be negative.");
        }

        if (request.MinPrice.HasValue &&
            request.MaxPrice.HasValue &&
            request.MinPrice.Value >
            request.MaxPrice.Value)
        {
            throw new BadRequestException(
                "Minimum price cannot be greater than maximum price.");
        }

        if (request.MinRating.HasValue &&
            (
                request.MinRating.Value < 0 ||
                request.MinRating.Value > 5
            ))
        {
            throw new BadRequestException(
                "Minimum rating must be between 0 and 5.");
        }

        var query =
            _context.Therapists
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.User.IsActive &&
                    !x.User.IsBlocked &&
                    x.VerificationStatus ==
                        TherapistVerificationStatus.Approved)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(
                request.SearchText))
        {
            var searchText =
                request.SearchText
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                (
                    x.User.FirstName
                    + " "
                    + x.User.LastName
                )
                .ToLower()
                .Contains(searchText)
                ||
                x.Specialization
                    .ToLower()
                    .Contains(searchText)
                ||
                x.City
                    .ToLower()
                    .Contains(searchText)
                ||
                x.Country
                    .ToLower()
                    .Contains(searchText)
                ||
                x.Address
                    .ToLower()
                    .Contains(searchText)
                ||
                (
                    x.Languages
                    ?? string.Empty
                )
                .ToLower()
                .Contains(searchText)
                ||
                x.TherapyApproaches.Any(ta =>
                    !ta.IsDeleted &&
                    !ta.TherapyApproach.IsDeleted &&
                    ta.TherapyApproach.IsActive &&
                    ta.TherapyApproach.Name
                        .ToLower()
                        .Contains(searchText)));
        }

        if (!string.IsNullOrWhiteSpace(
                request.Specialization))
        {
            var specialization =
                request.Specialization
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                x.Specialization
                    .ToLower()
                    .Contains(specialization));
        }

        if (request.TherapyApproachId.HasValue)
        {
            query = query.Where(x =>
                x.TherapyApproaches.Any(ta =>
                    !ta.IsDeleted &&
                    ta.TherapyApproachId ==
                        request.TherapyApproachId.Value &&
                    !ta.TherapyApproach.IsDeleted &&
                    ta.TherapyApproach.IsActive));
        }

        if (!string.IsNullOrWhiteSpace(
                request.Gender))
        {
            var gender =
                request.Gender
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                x.User.Gender != null &&
                x.User.Gender
                    .ToLower() == gender);
        }

        if (!string.IsNullOrWhiteSpace(
                request.Language))
        {
            var language =
                request.Language
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                x.Languages != null &&
                (
                    "," + x.Languages.ToLower() + ","
                )
                .Contains(
                    "," + language + ","));
        }

        if (!string.IsNullOrWhiteSpace(
                request.Location))
        {
            var location =
                request.Location
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                x.Country
                    .ToLower()
                    .Contains(location)
                ||
                x.City
                    .ToLower()
                    .Contains(location)
                ||
                x.Address
                    .ToLower()
                    .Contains(location)
                ||
                (
                    x.Location
                    ?? string.Empty
                )
                .ToLower()
                .Contains(location));
        }

        if (!string.IsNullOrWhiteSpace(
                request.SessionMode))
        {
            var sessionMode =
                request.SessionMode
                    .Trim()
                    .ToLower();

            query = sessionMode switch
            {
                "online" =>
                    query.Where(x =>
                        x.OffersOnline),

                "inperson" =>
                    query.Where(x =>
                        x.OffersInPerson),

                "both" =>
                    query.Where(x =>
                        x.OffersOnline &&
                        x.OffersInPerson),

                _ =>
                    throw new BadRequestException(
                        "Session mode must be online, inPerson or both.")
            };
        }

        if (request.MinPrice.HasValue)
        {
            query = query.Where(x =>
                x.HourlyRate >=
                request.MinPrice.Value);
        }

        if (request.MaxPrice.HasValue)
        {
            query = query.Where(x =>
                x.HourlyRate <=
                request.MaxPrice.Value);
        }

        if (request.MinRating.HasValue)
        {
            query = query.Where(x =>
                x.Reviews
.Where(review =>
    !review.IsDeleted)
                    .Any()
                &&
                x.Reviews
.Where(review =>
    !review.IsDeleted)
                    .Average(review =>
                        review.Rating)
                >= request.MinRating.Value);
        }

        if (request.AvailableDay.HasValue)
        {
            query = query.Where(x =>
                x.Availabilities.Any(
                    availability =>
                        !availability.IsDeleted &&
                        availability.DayOfWeek ==
                            request.AvailableDay.Value));
        }

        query =
            request.SortBy?
                .Trim()
                .ToLower() switch
            {
                "rating" =>
                    query
                        .OrderByDescending(x =>
                            x.Reviews
.Where(review =>
    !review.IsDeleted)
                                .Any()
                                ? x.Reviews
                                    .Where(review =>
                                        !review.IsDeleted &&
                                        review.IsApproved)
                                    .Average(review =>
                                        review.Rating)
                                : 0)
                        .ThenBy(x =>
                            x.Id),

                "price" =>
                    query
                        .OrderBy(x =>
                            x.HourlyRate)
                        .ThenBy(x =>
                            x.Id),

                "experience" =>
                    query
                        .OrderByDescending(x =>
                            x.ExperienceYears)
                        .ThenBy(x =>
                            x.Id),

                _ =>
                    query.OrderBy(x =>
                        x.Id)
            };

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .Skip(pagination.Skip)
                .Take(pagination.PageSize)
                .Select(x =>
                    new TherapistResponseDto
                    {
                        Id = x.Id,

                        UserId = x.UserId,

                        FullName =
                            x.User.FirstName
                            + " "
                            + x.User.LastName,

                        Email =
                            x.User.Email
                            ?? string.Empty,

                        Specialization =
                            x.Specialization,

                        Biography =
                            x.Biography,

                        HourlyRate =
                            x.HourlyRate,

                        ExperienceYears =
                            x.ExperienceYears,

                        AverageRating =
                            x.Reviews
.Where(review =>
    !review.IsDeleted)
                                .Any()
                                ? Math.Round(
                                    x.Reviews
                                        .Where(review =>
                                            !review.IsDeleted &&
                                            review.IsApproved)
                                        .Average(review =>
                                            review.Rating),
                                    1)
                                : 0,

                        TotalReviews =
                            x.Reviews.Count(review =>
    !review.IsDeleted),

                        VerificationStatus =
                            x.VerificationStatus
                                .ToString(),

                        VerificationNotes =
                            x.VerificationNotes,

                        ProfileImageUrl =
                            x.User.ProfileImageUrl
                            ?? x.ProfileImagePath,

                        Country =
                            x.Country,

                        City =
                            x.City,

                        Address =
                            x.Address,

                        OffersOnline =
                            x.OffersOnline,

                        OffersInPerson =
                            x.OffersInPerson,

                        Latitude =
                            x.Latitude,

                        Longitude =
                            x.Longitude,

                        TherapyApproaches =
                            x.TherapyApproaches
                                .Where(ta =>
                                    !ta.IsDeleted &&
                                    !ta.TherapyApproach.IsDeleted &&
                                    ta.TherapyApproach.IsActive)
                                .OrderBy(ta =>
                                    ta.TherapyApproach.Name)
                                .Select(ta =>
                                    ta.TherapyApproach.Name)
                                .ToList()
                    })
                .ToListAsync();

        return PagedResponse<TherapistResponseDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<List<TherapistResponseDto>>
    FilterAsync(
        TherapistFilterDto filter)
    {
        var query =
            _context.Therapists
                .Include(x => x.User)
                .Include(x => x.Reviews)
.Where(x =>
    !x.IsDeleted &&
    x.VerificationStatus ==
        TherapistVerificationStatus.Approved)
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

                    TotalReviews = x.Reviews.Count,
                    ProfileImageUrl = x.User.ProfileImageUrl ?? x.ProfileImagePath,
                    Country = x.Country,
                    City = x.City,
                    Address = x.Address,
                    OffersOnline = x.OffersOnline,
                    OffersInPerson = x.OffersInPerson,
                    Latitude = x.Latitude,
                    Longitude = x.Longitude,

                    VerificationStatus = x.VerificationStatus.ToString(),

                    TherapyApproaches = x.TherapyApproaches
    .Where(ta =>
        !ta.IsDeleted &&
        !ta.TherapyApproach.IsDeleted &&
        ta.TherapyApproach.IsActive)
    .OrderBy(ta => ta.TherapyApproach.Name)
    .Select(ta => ta.TherapyApproach.Name)
    .ToList(),

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

    public async Task<TherapistProfileDto> GetProfileAsync(
    int therapistUserId)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .Include(x => x.User)
                .Include(x => x.Availabilities)
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist profile not found.");
        }

        var languages =
            string.IsNullOrWhiteSpace(therapist.Languages)
                ? new List<string>()
                : therapist.Languages
                    .Split(
                        ',',
                        StringSplitOptions.RemoveEmptyEntries |
                        StringSplitOptions.TrimEntries)
                    .Where(x =>
                        !string.IsNullOrWhiteSpace(x))
                    .Distinct(
                        StringComparer.OrdinalIgnoreCase)
                    .ToList();

        return new TherapistProfileDto
        {
            TherapistId =
                therapist.Id,

            UserId =
                therapist.UserId,

            FirstName =
                therapist.User.FirstName
                ?? string.Empty,

            LastName =
                therapist.User.LastName
                ?? string.Empty,

            FullName =
                string.Join(
                    " ",
                    new[]
                    {
                    therapist.User.FirstName,
                    therapist.User.LastName
                    }
                    .Where(x =>
                        !string.IsNullOrWhiteSpace(x))),

            Email =
                therapist.User.Email
                ?? string.Empty,

            PhoneNumber =
                therapist.User.PhoneNumber,

            Biography =
                therapist.Biography,

            Specialization =
                therapist.Specialization,

            ExperienceYears =
                therapist.ExperienceYears,

            HourlyRate =
                therapist.HourlyRate,

            Location =
                therapist.Location
                ?? string.Empty,

            Languages =
                languages,

            ProfileImageUrl =
                therapist.User.ProfileImageUrl
                ?? therapist.ProfileImagePath,

            VerificationStatus =
                therapist.VerificationStatus
                    .ToString(),

            Availabilities =
                therapist.Availabilities
                    .OrderBy(x =>
                        x.DayOfWeek)
                    .ThenBy(x =>
                        x.StartTime)
                    .Select(x =>
                        new AvailabilityResponseDto
                        {
                            Id =
                                x.Id,

                            DayOfWeek =
                                x.DayOfWeek,

                            StartTime =
                                x.StartTime,

                            EndTime =
                                x.EndTime
                        })
                    .ToList(),

            Country = therapist.Country,
            City = therapist.City,
            Address = therapist.Address,
            OffersOnline = therapist.OffersOnline,
            OffersInPerson = therapist.OffersInPerson,
            Latitude = therapist.Latitude,
            Longitude = therapist.Longitude,
        };
    }

    public async Task UpdateProfileAsync(
     int therapistUserId,
     UpdateTherapistProfileDto request)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist profile not found.");
        }

        var biography =
            request.Biography.Trim();

        var specialization =
            request.Specialization.Trim();

        var location =
            request.Location.Trim();

        var languages =
            request.Languages
                .Where(x =>
                    !string.IsNullOrWhiteSpace(x))
                .Select(x =>
                    x.Trim())
                .Distinct(
                    StringComparer.OrdinalIgnoreCase)
                .ToList();

       

        var serializedLanguages =
            string.Join(",", languages);

        therapist.Biography =
            biography;

        therapist.Specialization =
            specialization;

        therapist.ExperienceYears =
            request.ExperienceYears;

        therapist.HourlyRate =
            request.HourlyRate;

        therapist.Location =
            location;

        therapist.Languages =
            serializedLanguages;

        therapist.Country = request.Country.Trim();
        therapist.City = request.City.Trim();
        therapist.Address = request.Address.Trim();
        therapist.OffersOnline = request.OffersOnline;
        therapist.OffersInPerson = request.OffersInPerson;

        await UpdateCoordinatesAsync(
            therapist,
            CancellationToken.None);

        await _context.SaveChangesAsync();
    }

    public async Task<TherapistProfileImageDto>
    UploadProfileImageAsync(
        int therapistUserId,
        IFormFile file)
    {
        var therapist =
            await _context.Therapists
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist profile not found.");
        }

        if (file == null || file.Length == 0)
        {
            throw new ArgumentException(
                "Profile image is required.");
        }

        const long maximumFileSize =
            5 * 1024 * 1024;

        if (file.Length > maximumFileSize)
        {
            throw new ArgumentException(
                "Profile image cannot be larger than 5 MB.");
        }

        var allowedContentTypes =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "image/jpeg",
            "image/png",
            "image/webp"
            };

        if (!allowedContentTypes.Contains(
                file.ContentType))
        {
            throw new ArgumentException(
                "Only JPG, PNG and WEBP images are allowed.");
        }

        var extension =
            Path.GetExtension(file.FileName)
                .ToLowerInvariant();

        var allowedExtensions =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            ".jpg",
            ".jpeg",
            ".png",
            ".webp"
            };

        if (!allowedExtensions.Contains(extension))
        {
            throw new ArgumentException(
                "Unsupported profile image extension.");
        }

        var webRootPath =
            _environment.WebRootPath
            ?? Path.Combine(
                Directory.GetCurrentDirectory(),
                "wwwroot");

        var uploadsFolder =
            Path.Combine(
                webRootPath,
                "uploads",
                "profiles",
                "therapists");

        Directory.CreateDirectory(
            uploadsFolder);

        var uniqueFileName =
            $"{Guid.NewGuid():N}{extension}";

        var physicalFilePath =
            Path.Combine(
                uploadsFolder,
                uniqueFileName);

        await using (var stream =
            new FileStream(
                physicalFilePath,
                FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var oldImageUrl =
            therapist.User.ProfileImageUrl
            ?? therapist.ProfileImagePath;

        var profileImageUrl =
            $"/uploads/profiles/therapists/{uniqueFileName}";

        therapist.User.ProfileImageUrl =
            profileImageUrl;

        therapist.ProfileImagePath =
            profileImageUrl;

        await _context.SaveChangesAsync();

        DeleteOldProfileImage(
            oldImageUrl,
            profileImageUrl,
            webRootPath);

        return new TherapistProfileImageDto
        {
            ProfileImageUrl =
                profileImageUrl
        };
    }

    public async Task<TherapistDetailsDto>
 GetByIdAsync(
     int therapistId,
     int? currentUserId)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .Include(x => x.User)
                .Include(x => x.Reviews)
                .Include(x => x.Availabilities)
                .Include(x => x.TherapyApproaches)
                    .ThenInclude(x =>
                        x.TherapyApproach)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId &&
                    !x.IsDeleted &&
                    x.VerificationStatus ==
                        TherapistVerificationStatus
                            .Approved);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found or is not publicly available.");
        }

        int? chatAppointmentId = null;

        if (currentUserId.HasValue)
        {
            chatAppointmentId =
                await _context.Appointments
                    .AsNoTracking()
                    .Where(appointment =>
                        !appointment.IsDeleted &&
                        appointment.TherapistId ==
                            therapistId &&
                        appointment.Client.UserId ==
                            currentUserId.Value &&
                        (
                            appointment.Status ==
                                AppointmentStatus.Accepted ||
                            appointment.Status ==
                                AppointmentStatus.Completed
                        ))
                    .OrderByDescending(appointment =>
                        appointment.Status ==
                        AppointmentStatus.Accepted)
                    .ThenByDescending(appointment =>
                        appointment.StartUtc)
                    .Select(appointment =>
                        (int?)appointment.Id)
                    .FirstOrDefaultAsync();
        }

        var languages =
            string.IsNullOrWhiteSpace(
                therapist.Languages)
                ? new List<string>()
                : therapist.Languages
                    .Split(
                        ',',
                        StringSplitOptions
                            .RemoveEmptyEntries |
                        StringSplitOptions
                            .TrimEntries)
                    .Where(language =>
                        !string.IsNullOrWhiteSpace(
                            language))
                    .Distinct(
                        StringComparer
                            .OrdinalIgnoreCase)
                    .ToList();

        return new TherapistDetailsDto
        {
            Id =
                therapist.Id,

            FullName =
                therapist.User.FirstName
                + " "
                + therapist.User.LastName,

            Email =
                therapist.User.Email
                ?? string.Empty,

            Biography =
                therapist.Biography,

            Specialization =
                therapist.Specialization,

            TherapyApproaches =
                therapist.TherapyApproaches
                    .Where(therapyApproach =>
                        !therapyApproach.IsDeleted &&
                        !therapyApproach
                            .TherapyApproach
                            .IsDeleted &&
                        therapyApproach
                            .TherapyApproach
                            .IsActive)
                    .OrderBy(therapyApproach =>
                        therapyApproach
                            .TherapyApproach
                            .Name)
                    .Select(therapyApproach =>
                        therapyApproach
                            .TherapyApproach
                            .Name)
                    .ToList(),

            Languages =
                languages,

            HourlyRate =
                therapist.HourlyRate,

            ExperienceYears =
                therapist.ExperienceYears,

            AverageRating =
                therapist.Reviews.Any(review =>
                    !review.IsDeleted &&
                    review.IsApproved)
                    ? Math.Round(
                        therapist.Reviews
                            .Where(review =>
                                !review.IsDeleted &&
                                review.IsApproved)
                            .Average(review =>
                                review.Rating),
                        1)
                    : 0,

            TotalReviews =
                therapist.Reviews.Count(review =>
                    !review.IsDeleted &&
                    review.IsApproved),

            VerificationStatus =
                therapist.VerificationStatus
                    .ToString(),

            Availabilities =
                therapist.Availabilities
                    .Where(availability =>
                        !availability.IsDeleted)
                    .OrderBy(availability =>
                        availability.DayOfWeek)
                    .ThenBy(availability =>
                        availability.StartTime)
                    .Select(availability =>
                        new AvailabilityResponseDto
                        {
                            Id =
                                availability.Id,

                            DayOfWeek =
                                availability.DayOfWeek,

                            StartTime =
                                availability.StartTime,

                            EndTime =
                                availability.EndTime
                        })
                    .ToList(),

            ProfileImageUrl =
                therapist.User.ProfileImageUrl
                ?? therapist.ProfileImagePath,

            Country =
                therapist.Country,

            City =
                therapist.City,

            Address =
                therapist.Address,

            OffersOnline =
                therapist.OffersOnline,

            OffersInPerson =
                therapist.OffersInPerson,

            Latitude =
                therapist.Latitude,

            Longitude =
                therapist.Longitude,

            CanChat =
                chatAppointmentId.HasValue,

            ChatAppointmentId =
                chatAppointmentId
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
            throw new NotFoundException("Therapist not found.");
        }

        var availability =
            await _context.TherapistAvailabilities
                .FirstOrDefaultAsync(x =>
                    x.Id == availabilityId
                    && x.TherapistId == therapist.Id);

        if (availability == null)
        {
            throw new NotFoundException(
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
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var todayStartUtc =
            DateTime.UtcNow.Date;

        var tomorrowStartUtc =
            todayStartUtc.AddDays(1);

        var todayAppointments =
            await _context.Appointments
                .AsNoTracking()
                .CountAsync(x =>
                    !x.IsDeleted &&
                    x.TherapistId == therapist.Id &&
                    x.Status ==
                        AppointmentStatus.Accepted &&
                    x.StartUtc >= todayStartUtc &&
                    x.StartUtc < tomorrowStartUtc);

        var upcomingAppointments =
            await _context.Appointments
                .AsNoTracking()
                .CountAsync(x =>
                    !x.IsDeleted &&
                    x.TherapistId == therapist.Id &&
                    x.Status ==
                        AppointmentStatus.Accepted &&
                    x.StartUtc >= tomorrowStartUtc);

        var totalClients =
            await _context.Appointments
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.TherapistId == therapist.Id &&
                    (
                        x.Status ==
                            AppointmentStatus.Accepted ||
                        x.Status ==
                            AppointmentStatus.Completed
                    ))
                .Select(x => x.ClientId)
                .Distinct()
                .CountAsync();

        var newRequests =
            await _context.Appointments
                .AsNoTracking()
                .CountAsync(x =>
                    !x.IsDeleted &&
                    x.TherapistId == therapist.Id &&
                    x.Status ==
                        AppointmentStatus.Pending);

        var unreadMessages =
            await _context.Conversations
                .AsNoTracking()
                .Where(conversation =>
                    !conversation.IsDeleted &&
                    conversation.Participants.Any(
                        participant =>
                            participant.UserId ==
                                therapistUserId &&
                            participant.IsActive &&
                            !participant.IsDeleted))
                .SumAsync(conversation =>
                    conversation.Messages.Count(message =>
                        !message.IsDeleted &&
                        message.SenderUserId !=
                            therapistUserId &&
                        (
                            conversation.Participants
                                .Where(participant =>
                                    participant.UserId ==
                                        therapistUserId &&
                                    participant.IsActive &&
                                    !participant.IsDeleted)
                                .Select(participant =>
                                    participant.LastReadAtUtc)
                                .FirstOrDefault() == null
                            ||
                            message.SentAtUtc >
                                conversation.Participants
                                    .Where(participant =>
                                        participant.UserId ==
                                            therapistUserId &&
                                        participant.IsActive &&
                                        !participant.IsDeleted)
                                    .Select(participant =>
                                        participant.LastReadAtUtc)
                                    .FirstOrDefault()
                        )));

        var averageRating =
            await _context.Reviews
                .AsNoTracking()
                .Where(review =>
                    !review.IsDeleted &&
                    review.IsApproved &&
                    review.TherapistId ==
                        therapist.Id)
                .Select(review =>
                    (double?)review.Rating)
                .AverageAsync()
            ?? 0;

        var totalEarnings =
            await _context.Payments
                .AsNoTracking()
                .Where(payment =>
                    !payment.IsDeleted &&
                    payment.Status ==
                        PaymentStatus.Paid &&
                    payment.Appointment.TherapistId ==
                        therapist.Id)
                .SumAsync(payment =>
                    (decimal?)payment.Amount)
            ?? 0;

        return new TherapistDashboardDto
        {
            TodayAppointments =
                todayAppointments,

            UpcomingAppointments =
                upcomingAppointments,

            TotalClients =
                totalClients,

            NewRequests =
                newRequests,

            UnreadMessages =
                unreadMessages,

            AverageRating =
                Math.Round(
                    averageRating,
                    1),

            TotalEarnings =
                totalEarnings
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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
            throw new NotFoundException(
                "Therapist not found.");
        }

        await ValidateDocumentAsync(file);

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

        var extension =
            Path.GetExtension(file.FileName)
                .ToLowerInvariant();

        var uniqueFileName =
            $"{Guid.NewGuid():N}{extension}";

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

                FileName = uniqueFileName,

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
            throw new NotFoundException(
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
            throw new NotFoundException(
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

    public async Task<List<TherapistClientListDto>>
    GetClientsAsync(
        int therapistUserId,
        string? search)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var normalizedSearch =
            search?.Trim().ToLower();

        var appointments =
            _context.Appointments
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Where(x =>
                    x.TherapistId == therapist.Id);

        if (!string.IsNullOrWhiteSpace(
                normalizedSearch))
        {
            appointments =
                appointments.Where(x =>
                    (
                        x.Client.User.FirstName
                        + " "
                        + x.Client.User.LastName
                    )
                    .ToLower()
                    .Contains(normalizedSearch)
                    ||
                    (
                        x.Client.User.Email
                        ?? string.Empty
                    )
                    .ToLower()
                    .Contains(normalizedSearch)
                    ||
                    (
                        x.Client.User.PhoneNumber
                        ?? string.Empty
                    )
                    .ToLower()
                    .Contains(normalizedSearch));
        }

        var clients =
            await appointments
                .GroupBy(x => new
                {
                    ClientId =
                        x.ClientId,

                    x.Client.UserId,

                    x.Client.User.FirstName,

                    x.Client.User.LastName,

                    x.Client.User.Email,

                    x.Client.User.PhoneNumber
                })
                .Select(group =>
                    new TherapistClientListDto
                    {
                        ClientId =
                            group.Key.ClientId,

                        UserId =
                            group.Key.UserId,

                        FullName =
                            group.Key.FirstName
                            + " "
                            + group.Key.LastName,

                        Email =
                            group.Key.Email
                            ?? string.Empty,

                        PhoneNumber =
                            group.Key.PhoneNumber,

                        TotalAppointments =
                            group.Count(),

                        CompletedAppointments =
                            group.Count(x =>
                                x.Status ==
                                AppointmentStatus
                                    .Completed),

                        LastAppointmentDate =
                            group
                                .Where(x =>
                                    x.EndUtc <
                                    DateTime.UtcNow)
                                .OrderByDescending(x =>
                                    x.EndUtc)
                                .Select(x =>
                                    (DateTime?)x.EndUtc)
                                .FirstOrDefault(),

                        NextAppointmentDate =
                            group
                                .Where(x =>
                                    x.StartUtc >
                                    DateTime.UtcNow &&
                                    (
                                        x.Status ==
                                        AppointmentStatus
                                            .Pending
                                        ||
                                        x.Status ==
                                        AppointmentStatus
                                            .Accepted
                                    ))
                                .OrderBy(x =>
                                    x.StartUtc)
                                .Select(x =>
                                    (DateTime?)x.StartUtc)
                                .FirstOrDefault()
                    })
                .OrderByDescending(x =>
                    x.NextAppointmentDate
                    != null)
                .ThenBy(x =>
                    x.NextAppointmentDate)
                .ThenByDescending(x =>
                    x.LastAppointmentDate)
                .ThenBy(x =>
                    x.FullName)
                .ToListAsync();

        return clients;
    }

    public async Task<TherapistClientDetailsDto>
    GetClientDetailsAsync(
        int therapistUserId,
        int clientId)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.UserId == therapistUserId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var appointments =
            await _context.Appointments
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Where(x =>
                    x.TherapistId == therapist.Id &&
                    x.ClientId == clientId)
                .OrderByDescending(x =>
                    x.StartUtc)
                .ToListAsync();

        if (appointments.Count == 0)
        {
            throw new NotFoundException(
                "Client not found or does not belong to this therapist.");
        }

        var client =
            appointments[0].Client;

        var appointmentIds =
            appointments
                .Select(x => x.Id)
                .ToList();

        var appointmentIdsWithNotes =
            await _context.AppointmentNotes
                .AsNoTracking()
                .Where(x =>
                    x.TherapistId == therapist.Id &&
                    appointmentIds.Contains(
                        x.AppointmentId))
                .Select(x =>
                    x.AppointmentId)
                .ToHashSetAsync();

        var now =
            DateTime.UtcNow;

        var firstAppointmentDate =
            appointments
                .OrderBy(x =>
                    x.StartUtc)
                .Select(x =>
                    (DateTime?)x.StartUtc)
                .FirstOrDefault();

        var lastAppointmentDate =
            appointments
                .Where(x =>
                    x.EndUtc < now)
                .OrderByDescending(x =>
                    x.EndUtc)
                .Select(x =>
                    (DateTime?)x.EndUtc)
                .FirstOrDefault();

        var nextAppointmentDate =
            appointments
                .Where(x =>
                    x.StartUtc > now &&
                    (
                        x.Status ==
                        AppointmentStatus.Pending
                        ||
                        x.Status ==
                        AppointmentStatus.Accepted
                    ))
                .OrderBy(x =>
                    x.StartUtc)
                .Select(x =>
                    (DateTime?)x.StartUtc)
                .FirstOrDefault();

        return new TherapistClientDetailsDto
        {
            ClientId =
                client.Id,

            UserId =
                client.UserId,

            FullName =
                client.User.FirstName
                + " "
                + client.User.LastName,

            Email =
                client.User.Email
                ?? string.Empty,

            PhoneNumber =
                client.User.PhoneNumber,

            TotalAppointments =
                appointments.Count,

            PendingAppointments =
                appointments.Count(x =>
                    x.Status ==
                    AppointmentStatus.Pending),

            AcceptedAppointments =
                appointments.Count(x =>
                    x.Status ==
                    AppointmentStatus.Accepted),

            CompletedAppointments =
                appointments.Count(x =>
                    x.Status ==
                    AppointmentStatus.Completed),

            CancelledAppointments =
                appointments.Count(x =>
                    x.Status ==
                    AppointmentStatus.Cancelled
                    ||
                    x.Status ==
                    AppointmentStatus.Rejected),

            FirstAppointmentDate =
                firstAppointmentDate,

            LastAppointmentDate =
                lastAppointmentDate,

            NextAppointmentDate =
                nextAppointmentDate,

            AppointmentHistory =
                appointments
                    .Select(x =>
                        new TherapistClientAppointmentDto
                        {
                            AppointmentId =
                                x.Id,

                            StartUtc =
                                x.StartUtc,

                            EndUtc =
                                x.EndUtc,

                            Status =
                                x.Status.ToString(),

                            Type =
                                x.Type.ToString(),

                            MeetingLink =
                                x.MeetingLink,

                            Location =
                                x.Location,

                            HasNote =
                                appointmentIdsWithNotes
                                    .Contains(x.Id)
                        })
                    .ToList()
        };
    }

    private static void DeleteOldProfileImage(
    string? oldImageUrl,
    string newImageUrl,
    string webRootPath)
    {
        if (string.IsNullOrWhiteSpace(
                oldImageUrl) ||
            string.Equals(
                oldImageUrl,
                newImageUrl,
                StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        const string managedFolder =
            "/uploads/profiles/therapists/";

        if (!oldImageUrl.StartsWith(
                managedFolder,
                StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var relativePath =
            oldImageUrl
                .TrimStart('/')
                .Replace(
                    '/',
                    Path.DirectorySeparatorChar);

        var physicalPath =
            Path.Combine(
                webRootPath,
                relativePath);

        if (File.Exists(physicalPath))
        {
            File.Delete(physicalPath);
        }
    }

    private static async Task ValidateDocumentAsync(
    IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            throw new BadRequestException(
                "Select a document.");
        }

        if (file.Length > MaximumDocumentSize)
        {
            throw new BadRequestException(
                "Maximum document size is 10 MB.");
        }

        var extension =
            Path.GetExtension(file.FileName);

        if (string.IsNullOrWhiteSpace(extension) ||
            !AllowedDocumentExtensions.Contains(extension))
        {
            throw new BadRequestException(
                "Only JPG, JPEG, PNG and PDF files are allowed.");
        }

        if (string.IsNullOrWhiteSpace(file.ContentType) ||
            !AllowedDocumentMimeTypes.Contains(file.ContentType))
        {
            throw new BadRequestException(
                "Unsupported content type.");
        }

        var header = new byte[8];

        await using var stream =
            file.OpenReadStream();

        var bytesRead =
            await stream.ReadAsync(
                header.AsMemory(0, header.Length));

        var isJpeg =
            bytesRead >= 3 &&
            header[0] == 0xFF &&
            header[1] == 0xD8 &&
            header[2] == 0xFF;

        var isPng =
            bytesRead >= 8 &&
            header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4E &&
            header[3] == 0x47 &&
            header[4] == 0x0D &&
            header[5] == 0x0A &&
            header[6] == 0x1A &&
            header[7] == 0x0A;

        var isPdf =
            bytesRead >= 4 &&
            header[0] == 0x25 &&
            header[1] == 0x50 &&
            header[2] == 0x44 &&
            header[3] == 0x46;

        if (!isJpeg && !isPng && !isPdf)
        {
            throw new BadRequestException(
                "Invalid file format.");
        }
    }

    private async Task UpdateCoordinatesAsync(
    Therapist therapist,
    CancellationToken cancellationToken)
    {
        if (!therapist.OffersInPerson)
        {
            therapist.Latitude = null;
            therapist.Longitude = null;
            return;
        }

        if (string.IsNullOrWhiteSpace(therapist.Country) ||
            string.IsNullOrWhiteSpace(therapist.City))
        {
            therapist.Latitude = null;
            therapist.Longitude = null;
            return;
        }

        var result = await _geocodingService.GeocodeAddressAsync(
            therapist.Country,
            therapist.City,
            therapist.Address,
            cancellationToken);

        if (!result.IsSuccessful ||
            result.Latitude is null ||
            result.Longitude is null)
        {
            therapist.Latitude = null;
            therapist.Longitude = null;
            return;
        }

        therapist.Latitude = result.Latitude;
        therapist.Longitude = result.Longitude;
    }
}