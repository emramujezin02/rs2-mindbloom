using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Models;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly UserManager<ApplicationUser> _userManager;

    private readonly ApplicationDbContext _context;

    private readonly INotificationSender _notificationSender;

    public AdminService(
    UserManager<ApplicationUser> userManager,
    ApplicationDbContext context,
    INotificationSender notificationSender)
    {
        _userManager = userManager;

        _context = context;

        _notificationSender =
            notificationSender;
    }

    public async Task<PagedResponse<UserListDto>>
        GetUsersAsync(
            SearchAdminUsersDto request)
    {
        var query =
            _context.Users
                .AsNoTracking()
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(
                request.Search))
        {
            var search =
                request.Search
                    .Trim()
                    .ToLower();

            query = query.Where(user =>
                user.FirstName
                    .ToLower()
                    .Contains(search)
                || user.LastName
                    .ToLower()
                    .Contains(search)
                || (
                    user.FirstName
                    + " "
                    + user.LastName
                )
                .ToLower()
                .Contains(search)
                || (
                    user.Email ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                || (
                    user.UserName ?? string.Empty
                )
                .ToLower()
                .Contains(search));
        }

        if (request.IsBlocked.HasValue)
        {
            query = query.Where(user =>
                user.IsBlocked ==
                request.IsBlocked.Value);
        }

        if (!string.IsNullOrWhiteSpace(
                request.Role))
        {
            var roleName =
                request.Role.Trim();

            query = query.Where(user =>
                _context.UserRoles
                    .Where(userRole =>
                        userRole.UserId ==
                        user.Id)
                    .Join(
                        _context.Roles,
                        userRole =>
                            userRole.RoleId,
                        role =>
                            role.Id,
                        (
                            userRole,
                            role
                        ) =>
                            role.Name)
                    .Any(name =>
                        name == roleName));
        }

        var totalCount =
            await query.CountAsync();

        var users =
            await query
                .OrderByDescending(user =>
                    user.CreatedAtUtc)
                .ThenBy(user =>
                    user.LastName)
                .ThenBy(user =>
                    user.FirstName)
                .Skip(
                    (
                        request.PageNumber - 1
                    )
                    * request.PageSize)
                .Take(request.PageSize)
                .Select(user =>
                    new UserListDto
                    {
                        Id =
                            user.Id,

                        FirstName =
                            user.FirstName,

                        LastName =
                            user.LastName,

                        FullName =
                            user.FirstName
                            + " "
                            + user.LastName,

                        Email =
                            user.Email
                            ?? string.Empty,

                        Role =
                            _context.UserRoles
                                .Where(
                                    userRole =>
                                        userRole.UserId
                                        == user.Id)
                                .Join(
                                    _context.Roles,
                                    userRole =>
                                        userRole.RoleId,
                                    role =>
                                        role.Id,
                                    (
                                        userRole,
                                        role
                                    ) =>
                                        role.Name)
                                .FirstOrDefault()
                            ?? "No Role",

                        IsEmailVerified =
                            user.IsEmailVerified
                            || user.EmailConfirmed,

                        IsBlocked =
                            user.IsBlocked,

                        CreatedAtUtc =
                            user.CreatedAtUtc
                    })
                .ToListAsync();

        return new PagedResponse<UserListDto>
        {
            Items = users,

            PageNumber =
                request.PageNumber,

            PageSize =
                request.PageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalCount == 0
                    ? 0
                    : (int)Math.Ceiling(
                        totalCount
                        / (double)request.PageSize)
        };
    }

    public async Task UpdateUserStatusAsync(
        int authenticatedAdminUserId,
        int userId,
        UpdateUserStatusDto request)
    {
        var user =
            await _userManager
                .FindByIdAsync(
                    userId.ToString());

        if (user == null)
        {
            throw new Exception(
                "User not found.");
        }

        if (
            authenticatedAdminUserId ==
            userId
            && request.IsBlocked)
        {
            throw new Exception(
                "You cannot deactivate your own administrator account.");
        }

        var targetUserRoles =
            await _userManager
                .GetRolesAsync(user);

        var isAdministrator =
            targetUserRoles.Contains(
                RoleConstants.Admin);

        if (
            request.IsBlocked
            && isAdministrator)
        {
            var activeAdminCount =
                await (
                    from adminUser
                        in _context.Users

                    join userRole
                        in _context.UserRoles
                        on adminUser.Id
                        equals userRole.UserId

                    join role
                        in _context.Roles
                        on userRole.RoleId
                        equals role.Id

                    where
                        role.Name ==
                            RoleConstants.Admin
                        && !adminUser.IsBlocked

                    select adminUser.Id
                )
                .Distinct()
                .CountAsync();

            if (activeAdminCount <= 1)
            {
                throw new Exception(
                    "The last active administrator account cannot be deactivated.");
            }
        }

        if (
            user.IsBlocked ==
            request.IsBlocked)
        {
            return;
        }

        user.IsBlocked =
            request.IsBlocked;

        user.IsActive =
            !request.IsBlocked;

        var result =
            await _userManager
                .UpdateAsync(user);

        if (!result.Succeeded)
        {
            var errorMessage =
                string.Join(
                    ", ",
                    result.Errors.Select(
                        error =>
                            error.Description));

            throw new Exception(
                $"User status could not be updated: {errorMessage}");
        }
    }

    public async Task
    UpdateTherapistVerificationAsync(
        int authenticatedAdminUserId,
        int therapistId,
        UpdateTherapistVerificationDto request)
    {
        if (request.Status !=
                TherapistVerificationStatus.Approved
            && request.Status !=
                TherapistVerificationStatus.Rejected)
        {
            throw new Exception(
                "Therapist may only be approved or rejected.");
        }

        var normalizedNotes =
            request.Notes?.Trim();

        if (request.Status ==
                TherapistVerificationStatus.Rejected
            && string.IsNullOrWhiteSpace(
                normalizedNotes))
        {
            throw new Exception(
                "Rejection reason is required.");
        }

        if (normalizedNotes?.Length > 1000)
        {
            throw new Exception(
                "Verification notes may contain at most 1000 characters.");
        }

        var admin =
            await _context.Users
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    authenticatedAdminUserId);

        if (admin == null)
        {
            throw new Exception(
                "Administrator not found.");
        }

        var isAdmin =
            await (
                from userRole
                    in _context.UserRoles

                join role
                    in _context.Roles
                    on userRole.RoleId
                    equals role.Id

                where
                    userRole.UserId ==
                        authenticatedAdminUserId
                    && role.Name ==
                        RoleConstants.Admin

                select userRole
            )
            .AnyAsync();

        if (!isAdmin)
        {
            throw new UnauthorizedAccessException(
                "Only administrators may verify therapists.");
        }

        var therapist =
            await _context.Therapists
                .Include(x => x.User)
                .Include(x => x.Documents)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId
                    && !x.IsDeleted);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        if (therapist.VerificationStatus !=
            TherapistVerificationStatus.Pending)
        {
            throw new Exception(
                "Only pending therapist applications may be processed.");
        }

        if (request.Status ==
                TherapistVerificationStatus.Approved
            && !therapist.Documents.Any(x =>
                !x.IsDeleted))
        {
            throw new Exception(
                "Therapist cannot be approved without uploaded verification documents.");
        }

        var previousStatus =
            therapist.VerificationStatus;

        await using var transaction =
            await _context.Database
                .BeginTransactionAsync();

        try
        {
            therapist.VerificationStatus =
                request.Status;

            therapist.VerificationNotes =
                normalizedNotes;

            if (request.Status ==
                TherapistVerificationStatus.Approved)
            {
                foreach (var document
                         in therapist.Documents
                             .Where(x =>
                                 !x.IsDeleted))
                {
                    document.IsApproved =
                        true;
                }
            }

            var audit =
                new TherapistVerificationAudit
                {
                    TherapistId =
                        therapist.Id,

                    AdminUserId =
                        authenticatedAdminUserId,

                    PreviousStatus =
                        previousStatus,

                    NewStatus =
                        request.Status,

                    Notes =
                        normalizedNotes,

                    ChangedAtUtc =
                        DateTime.UtcNow
                };

            _context
                .TherapistVerificationAudits
                .Add(audit);

            var approved =
                request.Status ==
                TherapistVerificationStatus.Approved;

            var notification =
                new Notification
                {
                    UserId =
                        therapist.UserId,

                    Title =
                        approved
                            ? "Therapist profile approved"
                            : "Therapist profile rejected",

                    Message =
                        approved
                            ? "Your therapist profile has been verified and approved."
                            : "Your therapist profile verification was rejected. "
                              + $"Reason: {normalizedNotes}",

                    IsRead =
                        false,

                    SentAtUtc =
                        DateTime.UtcNow
                };

            _context.Notifications.Add(
                notification);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();

            throw;
        }

        var realtimeTitle =
            request.Status ==
            TherapistVerificationStatus.Approved
                ? "Therapist profile approved"
                : "Therapist profile rejected";

        var realtimeMessage =
            request.Status ==
            TherapistVerificationStatus.Approved
                ? "Your therapist profile has been verified and approved."
                : "Your therapist profile verification was rejected. "
                  + $"Reason: {normalizedNotes}";

        await _notificationSender
            .SendToUserAsync(
                therapist.UserId,
                realtimeTitle,
                realtimeMessage);
    }

    public async Task<AdminDashboardDto>
        GetDashboardAsync()
    {
        return new AdminDashboardDto
        {
            TotalUsers =
                await _context.Users
                    .CountAsync(),

            TotalClients =
                await _context.Clients
                    .CountAsync(),

            TotalTherapists =
                await _context.Therapists
                    .CountAsync(),

            PendingTherapists =
                await _context.Therapists
                    .CountAsync(x =>
                        x.VerificationStatus ==
                        TherapistVerificationStatus
                            .Pending),

            ApprovedTherapists =
                await _context.Therapists
                    .CountAsync(x =>
                        x.VerificationStatus ==
                        TherapistVerificationStatus
                            .Approved),

            RejectedTherapists =
                await _context.Therapists
                    .CountAsync(x =>
                        x.VerificationStatus ==
                        TherapistVerificationStatus
                            .Rejected),

            TotalAppointments =
                await _context.Appointments
                    .CountAsync(),

            CompletedAppointments =
                await _context.Appointments
                    .CountAsync(x =>
                        x.Status ==
                        AppointmentStatus
                            .Completed),

            PendingAppointments =
                await _context.Appointments
                    .CountAsync(x =>
                        x.Status ==
                        AppointmentStatus
                            .Pending),

            CancelledAppointments =
                await _context.Appointments
                    .CountAsync(x =>
                        x.Status ==
                        AppointmentStatus
                            .Cancelled),

            TotalReviews =
                await _context.Reviews
                    .CountAsync(),

            TotalPayments =
                await _context.Payments
                    .CountAsync(),

            TotalRevenue =
                await _context.Payments
                    .Where(x =>
                        x.Status ==
                        PaymentStatus.Paid)
                    .SumAsync(x =>
                        (decimal?)x.Amount)
                ?? 0
        };
    }

    public async Task DeleteReviewAsync(
        int reviewId)
    {
        var review =
            await _context.Reviews
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId);

        if (review == null)
        {
            throw new Exception(
                "Review not found.");
        }

        _context.Reviews.Remove(review);

        await _context.SaveChangesAsync();
    }

    public async Task<
    PagedResponse<TherapistVerificationListDto>>
    GetPendingTherapistsAsync(
        SearchTherapistVerificationDto request)
    {
        var query =
            _context.Therapists
                .AsNoTracking()
                .Include(x => x.User)
                .Where(x =>
                    !x.IsDeleted
                    && x.VerificationStatus ==
                        TherapistVerificationStatus.Pending)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(
                request.Search))
        {
            var search =
                request.Search
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                (
                    x.User.FirstName
                    + " "
                    + x.User.LastName
                )
                .ToLower()
                .Contains(search)
                || (
                    x.User.Email
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                || x.Specialization
                    .ToLower()
                    .Contains(search));
        }

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderBy(x =>
                    x.CreatedAtUtc)
                .Skip(
                    (request.PageNumber - 1)
                    * request.PageSize)
                .Take(request.PageSize)
                .Select(x =>
                    new TherapistVerificationListDto
                    {
                        TherapistId =
                            x.Id,

                        UserId =
                            x.UserId,

                        FullName =
                            x.User.FirstName
                            + " "
                            + x.User.LastName,

                        Email =
                            x.User.Email
                            ?? string.Empty,

                        Specialization =
                            x.Specialization,

                        ExperienceYears =
                            x.ExperienceYears,

                        VerificationStatus =
                            x.VerificationStatus
                                .ToString(),

                        ProfileImageUrl =
                            x.User.ProfileImageUrl
                            ?? x.ProfileImagePath,

                        DocumentCount =
                            x.Documents.Count(
                                document =>
                                    !document.IsDeleted),

                        RegisteredAtUtc =
                            x.CreatedAtUtc
                    })
                .ToListAsync();

        return new PagedResponse<
            TherapistVerificationListDto>
        {
            Items = items,

            PageNumber =
                request.PageNumber,

            PageSize =
                request.PageSize,

            TotalCount =
                totalCount,

            TotalPages =
                totalCount == 0
                    ? 0
                    : (int)Math.Ceiling(
                        totalCount
                        / (double)request.PageSize)
        };
    }

    public async Task<
    TherapistVerificationDetailsDto>
    GetTherapistVerificationDetailsAsync(
        int therapistId)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .Include(x => x.User)
                .Include(x => x.Documents)
                .Include(x =>
                    x.VerificationAudits)
                    .ThenInclude(x =>
                        x.AdminUser)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId
                    && !x.IsDeleted);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        return new TherapistVerificationDetailsDto
        {
            TherapistId =
                therapist.Id,

            UserId =
                therapist.UserId,

            FullName =
                therapist.User.FirstName
                + " "
                + therapist.User.LastName,

            Email =
                therapist.User.Email
                ?? string.Empty,

            PhoneNumber =
                therapist.User.PhoneNumber,

            DateOfBirth =
                therapist.User.DateOfBirth,

            Biography =
                therapist.Biography,

            Specialization =
                therapist.Specialization,

            HourlyRate =
                therapist.HourlyRate,

            ExperienceYears =
                therapist.ExperienceYears,

            VerificationStatus =
                therapist.VerificationStatus
                    .ToString(),

            VerificationNotes =
                therapist.VerificationNotes,

            ProfileImageUrl =
                therapist.User.ProfileImageUrl
                ?? therapist.ProfileImagePath,

            RegisteredAtUtc =
                therapist.CreatedAtUtc,

            Documents =
                therapist.Documents
                    .Where(x =>
                        !x.IsDeleted)
                    .OrderByDescending(x =>
                        x.CreatedAtUtc)
                    .Select(x =>
                        new TherapistVerificationDocumentDto
                        {
                            Id =
                                x.Id,

                            FileName =
                                x.FileName,

                            FilePath =
                                x.FilePath,

                            ContentType =
                                x.ContentType,

                            IsApproved =
                                x.IsApproved,

                            CreatedAtUtc =
                                x.CreatedAtUtc
                        })
                    .ToList(),

            AuditHistory =
                therapist.VerificationAudits
                    .OrderByDescending(x =>
                        x.ChangedAtUtc)
                    .Select(x =>
                        new TherapistVerificationAuditDto
                        {
                            Id =
                                x.Id,

                            AdminName =
                                x.AdminUser.FirstName
                                + " "
                                + x.AdminUser.LastName,

                            PreviousStatus =
                                x.PreviousStatus
                                    .ToString(),

                            NewStatus =
                                x.NewStatus
                                    .ToString(),

                            Notes =
                                x.Notes,

                            ChangedAtUtc =
                                x.ChangedAtUtc
                        })
                    .ToList()
        };
    }
}