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
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;

namespace MindBloom.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly UserManager<ApplicationUser> _userManager;

    private readonly ApplicationDbContext _context;

    private readonly INotificationSender _notificationSender;

    private readonly IPaymentService _paymentService;

    private readonly IMembershipService _membershipService;
    public AdminService(
    UserManager<ApplicationUser> userManager,
    ApplicationDbContext context,
    INotificationSender notificationSender,
    IPaymentService paymentService,
    IMembershipService membershipService)
    {
        _userManager =
            userManager;

        _context =
            context;

        _notificationSender =
            notificationSender;

        _paymentService =
            paymentService;

        _membershipService =
            membershipService;
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

    public async Task<PagedResponse<AdminReviewListDto>>
        GetReviewsAsync(
            SearchAdminReviewsDto request)
    {
        if (request.Rating.HasValue &&
            (
                request.Rating.Value < 1 ||
                request.Rating.Value > 5
            ))
        {
            throw new Exception(
                "Rating filter must be between 1 and 5.");
        }

        var query =
            _context.Reviews
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .AsQueryable();

        if (request.IsDeleted.HasValue)
        {
            query = query.Where(x =>
                x.IsDeleted ==
                request.IsDeleted.Value);
        }
        else
        {
            query = query.Where(x =>
                !x.IsDeleted);
        }

        if (request.Rating.HasValue)
        {
            query = query.Where(x =>
                x.Rating ==
                request.Rating.Value);
        }

        if (request.HasTherapistReply.HasValue)
        {
            if (request.HasTherapistReply.Value)
            {
                query = query.Where(x =>
                    x.TherapistReply != null &&
                    x.TherapistReply != string.Empty);
            }
            else
            {
                query = query.Where(x =>
                    x.TherapistReply == null ||
                    x.TherapistReply == string.Empty);
            }
        }

        if (!string.IsNullOrWhiteSpace(
                request.Search))
        {
            var search =
                request.Search
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                (
                    x.Client.User.FirstName
                    + " "
                    + x.Client.User.LastName
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Client.User.Email
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Therapist.User.FirstName
                    + " "
                    + x.Therapist.User.LastName
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Therapist.User.Email
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                x.Comment
                    .ToLower()
                    .Contains(search)
                ||
                (
                    x.TherapistReply
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search));
        }

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    (request.PageNumber - 1)
                    * request.PageSize)
                .Take(request.PageSize)
                .Select(x =>
                    new AdminReviewListDto
                    {
                        Id =
                            x.Id,

                        AppointmentId =
                            x.AppointmentId,

                        ClientName =
                            x.Client.User.FirstName
                            + " "
                            + x.Client.User.LastName,

                        ClientEmail =
                            x.Client.User.Email
                            ?? string.Empty,

                        TherapistName =
                            x.Therapist.User.FirstName
                            + " "
                            + x.Therapist.User.LastName,

                        TherapistEmail =
                            x.Therapist.User.Email
                            ?? string.Empty,

                        Rating =
                            x.Rating,

                        Comment =
                            x.Comment,

                        HasTherapistReply =
                            x.TherapistReply != null
                            && x.TherapistReply !=
                                string.Empty,

                        IsDeleted =
                            x.IsDeleted,

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        ModeratedAtUtc =
                            x.ModeratedAtUtc
                    })
                .ToListAsync();

        return new PagedResponse<AdminReviewListDto>
        {
            Items =
                items,

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
                        totalCount /
                        (double)request.PageSize)
        };
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

    public async Task<AdminReviewDetailsDto>
    GetReviewDetailsAsync(
        int reviewId)
    {
        var review =
            await _context.Reviews
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.ModeratedByUser)
                .Include(x => x.ModerationAudits)
                    .ThenInclude(x => x.AdminUser)
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId);

        if (review == null)
        {
            throw new Exception(
                "Review not found.");
        }

        return new AdminReviewDetailsDto
        {
            Id =
                review.Id,

            AppointmentId =
                review.AppointmentId,

            ClientId =
                review.ClientId,

            ClientName =
                review.Client.User.FirstName
                + " "
                + review.Client.User.LastName,

            ClientEmail =
                review.Client.User.Email
                ?? string.Empty,

            TherapistId =
                review.TherapistId,

            TherapistName =
                review.Therapist.User.FirstName
                + " "
                + review.Therapist.User.LastName,

            TherapistEmail =
                review.Therapist.User.Email
                ?? string.Empty,

            Rating =
                review.Rating,

            Comment =
                review.Comment,

            CreatedAtUtc =
                review.CreatedAtUtc,

            TherapistReply =
                review.TherapistReply,

            TherapistReplyCreatedAtUtc =
                review.TherapistReplyCreatedAtUtc,

            IsDeleted =
                review.IsDeleted,

            ModerationReason =
                review.ModerationReason,

            ModeratedAtUtc =
                review.ModeratedAtUtc,

            ModeratedByAdminName =
                review.ModeratedByUser == null
                    ? null
                    : review.ModeratedByUser.FirstName
                      + " "
                      + review.ModeratedByUser.LastName,

            AuditHistory =
                review.ModerationAudits
                    .OrderByDescending(x =>
                        x.PerformedAtUtc)
                    .Select(x =>
                        new ReviewModerationAuditDto
                        {
                            Id =
                                x.Id,

                            Action =
                                x.Action.ToString(),

                            AdminName =
                                x.AdminUser.FirstName
                                + " "
                                + x.AdminUser.LastName,

                            AdminEmail =
                                x.AdminUser.Email
                                ?? string.Empty,

                            Reason =
                                x.Reason,

                            PerformedAtUtc =
                                x.PerformedAtUtc
                        })
                    .ToList()
        };
    }

    public async Task DeleteReviewAsync(
    int authenticatedAdminUserId,
    int reviewId,
    DeleteAdminReviewDto request)
    {
        var reason =
            request.Reason?.Trim()
            ?? string.Empty;

        if (string.IsNullOrWhiteSpace(
                reason))
        {
            throw new Exception(
                "Moderation reason is required.");
        }

        if (reason.Length < 5)
        {
            throw new Exception(
                "Moderation reason must contain at least 5 characters.");
        }

        if (reason.Length > 1000)
        {
            throw new Exception(
                "Moderation reason may contain at most 1000 characters.");
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

        var review =
            await _context.Reviews
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == reviewId);

        if (review == null)
        {
            throw new Exception(
                "Review not found.");
        }

        if (review.IsDeleted)
        {
            return;
        }

        var now =
            DateTime.UtcNow;

        await using var transaction =
            await _context.Database
                .BeginTransactionAsync();

        try
        {
            review.IsDeleted =
                true;

            review.ModerationReason =
                reason;

            review.ModeratedByUserId =
                authenticatedAdminUserId;

            review.ModeratedAtUtc =
                now;

            review.UpdatedAtUtc =
                now;

            var audit =
                new ReviewModerationAudit
                {
                    ReviewId =
                        review.Id,

                    AdminUserId =
                        authenticatedAdminUserId,

                    Action =
                        ReviewModerationAction
                            .Deleted,

                    Reason =
                        reason,

                    PerformedAtUtc =
                        now
                };

            _context
                .ReviewModerationAudits
                .Add(audit);

            _context.Notifications.Add(
                new Notification
                {
                    UserId =
                        review.Client.UserId,

                    AppointmentId =
                        review.AppointmentId,

                    Title =
                        "Review removed",

                    Message =
                        "Your review was removed by an administrator. "
                        + $"Reason: {reason}",

                    IsRead =
                        false,

                    SentAtUtc =
                        now
                });

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();

            throw;
        }

        await _notificationSender
            .SendToUserAsync(
                review.Client.UserId,
                "Review removed",
                "Your review was removed by an administrator. "
                + $"Reason: {reason}");
    }

    public async Task<
    PagedResponse<AdminAppointmentListDto>>
    GetAppointmentsAsync(
        SearchAdminAppointmentsDto request)
    {
        if (request.DateFromUtc.HasValue &&
            request.DateToUtc.HasValue &&
            request.DateFromUtc.Value >
            request.DateToUtc.Value)
        {
            throw new Exception(
                "Start date cannot be later than end date.");
        }

        var query =
            _context.Appointments
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Payment)
                .Where(x => !x.IsDeleted)
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
                    x.Client.User.FirstName
                    + " "
                    + x.Client.User.LastName
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Client.User.Email
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Therapist.User.FirstName
                    + " "
                    + x.Therapist.User.LastName
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Therapist.User.Email
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                x.Id.ToString()
                    .Contains(search));
        }

        if (request.Status.HasValue)
        {
            query = query.Where(x =>
                x.Status ==
                request.Status.Value);
        }

        if (request.Type.HasValue)
        {
            query = query.Where(x =>
                x.Type ==
                request.Type.Value);
        }

        if (request.IsPaid.HasValue)
        {
            query = query.Where(x =>
                x.IsPaid ==
                request.IsPaid.Value);
        }

        if (request.DateFromUtc.HasValue)
        {
            query = query.Where(x =>
                x.StartUtc >=
                request.DateFromUtc.Value);
        }

        if (request.DateToUtc.HasValue)
        {
            var exclusiveEnd =
                request.DateToUtc.Value.Date
                    .AddDays(1);

            query = query.Where(x =>
                x.StartUtc <
                exclusiveEnd);
        }

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderByDescending(x =>
                    x.StartUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    (request.PageNumber - 1)
                    * request.PageSize)
                .Take(request.PageSize)
                .Select(x =>
                    new AdminAppointmentListDto
                    {
                        Id =
                            x.Id,

                        ClientName =
                            x.Client.User.FirstName
                            + " "
                            + x.Client.User.LastName,

                        ClientEmail =
                            x.Client.User.Email
                            ?? string.Empty,

                        TherapistName =
                            x.Therapist.User.FirstName
                            + " "
                            + x.Therapist.User.LastName,

                        TherapistEmail =
                            x.Therapist.User.Email
                            ?? string.Empty,

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

                        IsPaid =
                            x.IsPaid,

                        PaymentStatus =
                            x.Payment == null
                                ? null
                                : x.Payment.Status
                                    .ToString(),

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        CanAdminCancel =
                            x.Status ==
                                AppointmentStatus.Pending
                            || x.Status ==
                                AppointmentStatus.Accepted
                    })
                .ToListAsync();

        return new PagedResponse<
            AdminAppointmentListDto>
        {
            Items =
                items,

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
                        totalCount /
                        (double)request.PageSize)
        };
    }

    public async Task<AdminAppointmentDetailsDto>
        GetAppointmentDetailsAsync(
            int appointmentId)
    {
        var appointment =
            await _context.Appointments
                .AsNoTracking()
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Payment)
                .Include(x => x.StatusAudits)
                    .ThenInclude(x =>
                        x.ChangedByUser)
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId &&
                    !x.IsDeleted);

        if (appointment == null)
        {
            throw new Exception(
                "Appointment not found.");
        }

        var membershipUsage =
            await _context.MembershipUsages
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.AppointmentId ==
                    appointment.Id);

        return new AdminAppointmentDetailsDto
        {
            Id =
                appointment.Id,

            ClientId =
                appointment.ClientId,

            ClientUserId =
                appointment.Client.UserId,

            ClientName =
                appointment.Client.User.FirstName
                + " "
                + appointment.Client.User.LastName,

            ClientEmail =
                appointment.Client.User.Email
                ?? string.Empty,

            TherapistId =
                appointment.TherapistId,

            TherapistUserId =
                appointment.Therapist.UserId,

            TherapistName =
                appointment.Therapist.User.FirstName
                + " "
                + appointment.Therapist.User.LastName,

            TherapistEmail =
                appointment.Therapist.User.Email
                ?? string.Empty,

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

            IsPaid =
                appointment.IsPaid,

            PaymentStatus =
                appointment.Payment?.Status
                    .ToString(),

            PaymentAmount =
                appointment.Payment?.Amount,

            StripePaymentIntentId =
                appointment.Payment?
                    .StripePaymentIntentId,

            RefundStatus =
                appointment.Payment == null
                    ? null
                    : appointment.Payment.Status
                        .ToString(),

            RefundReason =
                appointment.Payment?
                    .RefundReason,

            MeetingLink =
                appointment.MeetingLink,

            Location =
                appointment.Location,

            Notes =
                appointment.Notes,

            HasMembershipUsage =
                membershipUsage != null,

            MembershipUsageStatus =
                membershipUsage?.Status
                    .ToString(),

            CreatedAtUtc =
                appointment.CreatedAtUtc,

            UpdatedAtUtc =
                appointment.UpdatedAtUtc,

            CanAdminCancel =
                appointment.Status ==
                    AppointmentStatus.Pending
                || appointment.Status ==
                    AppointmentStatus.Accepted,

            AuditHistory =
                appointment.StatusAudits
                    .OrderByDescending(x =>
                        x.ChangedAtUtc)
                    .Select(x =>
                        new AdminAppointmentAuditDto
                        {
                            Id =
                                x.Id,

                            PreviousStatus =
                                x.PreviousStatus
                                    .HasValue
                                    ? x.PreviousStatus
                                        .Value
                                        .ToString()
                                    : null,

                            NewStatus =
                                x.NewStatus
                                    .ToString(),

                            Action =
                                x.Action,

                            Reason =
                                x.Reason,

                            ChangedByUserId =
                                x.ChangedByUserId,

                            ChangedByUserName =
                                x.ChangedByUser
                                    .FirstName
                                + " "
                                + x.ChangedByUser
                                    .LastName,

                            ChangedByUserEmail =
                                x.ChangedByUser.Email
                                ?? string.Empty,

                            ChangedAtUtc =
                                x.ChangedAtUtc
                        })
                    .ToList()
        };
    }

    public async Task CancelAppointmentAsync(
        int authenticatedAdminUserId,
        int appointmentId,
        AdminCancelAppointmentDto request)
    {
        var reason =
            request.Reason?.Trim()
            ?? string.Empty;

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

        if (reason.Length > 1000)
        {
            throw new Exception(
                "Cancellation reason may contain at most 1000 characters.");
        }

        var admin =
            await _context.Users
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    authenticatedAdminUserId
                    && !x.IsBlocked);

        if (admin == null)
        {
            throw new Exception(
                "Administrator not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Payment)
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId &&
                    !x.IsDeleted);

        if (appointment == null)
        {
            throw new Exception(
                "Appointment not found.");
        }

        if (appointment.Status ==
            AppointmentStatus.Cancelled)
        {
            return;
        }

        if (appointment.Status ==
                AppointmentStatus.Completed ||
            appointment.Status ==
                AppointmentStatus.Rejected)
        {
            throw new Exception(
                "A completed or rejected appointment cannot be cancelled.");
        }

        if (appointment.Status !=
                AppointmentStatus.Pending &&
            appointment.Status !=
                AppointmentStatus.Accepted)
        {
            throw new Exception(
                "Appointment is not in a cancellable state.");
        }

        var previousStatus =
            appointment.Status;

        /*
         * Administrator otkazuje termin zbog
         * administrativnog ili poslovnog razloga.
         * Membership sesija se zato vraća bez
         * primjene roka od 24 sata.
         */
        await _membershipService
            .HandleAppointmentCancellationAsync(
                appointment.Id,
                reason,
                forceRestore: true);

        if (appointment.Payment != null &&
            (
                appointment.Payment.Status ==
                    PaymentStatus.Paid
                || appointment.Payment.Status ==
                    PaymentStatus.RefundPending
                || appointment.Payment.Status ==
                    PaymentStatus.RefundFailed
                || appointment.Payment.Status ==
                    PaymentStatus.Refunded
            ))
        {
            await _paymentService
                .RefundAppointmentPaymentAsync(
                    appointment.Client.UserId,
                    appointment.Id,
                    reason);
        }

        var now =
            DateTime.UtcNow;

        appointment.Status =
            AppointmentStatus.Cancelled;

        appointment.UpdatedAtUtc =
            now;

        var audit =
            new AppointmentStatusAudit
            {
                AppointmentId =
                    appointment.Id,

                ChangedByUserId =
                    authenticatedAdminUserId,

                PreviousStatus =
                    previousStatus,

                NewStatus =
                    AppointmentStatus.Cancelled,

                Action =
                    "AdminCancellation",

                Reason =
                    reason,

                ChangedAtUtc =
                    now
            };

        _context.AppointmentStatusAudits.Add(
            audit);

        _context.Notifications.AddRange(
            new Notification
            {
                UserId =
                    appointment.Client.UserId,

                AppointmentId =
                    appointment.Id,

                Title =
                    "Appointment cancelled by administrator",

                Message =
                    "Your appointment was cancelled "
                    + "by an administrator. "
                    + $"Reason: {reason}",

                IsRead =
                    false,

                SentAtUtc =
                    now
            },
            new Notification
            {
                UserId =
                    appointment.Therapist.UserId,

                AppointmentId =
                    appointment.Id,

                Title =
                    "Appointment cancelled by administrator",

                Message =
                    "An appointment was cancelled "
                    + "by an administrator. "
                    + $"Reason: {reason}",

                IsRead =
                    false,

                SentAtUtc =
                    now
            });

        await _context.SaveChangesAsync();

        await _notificationSender
            .SendToUserAsync(
                appointment.Client.UserId,
                "Appointment cancelled by administrator",
                "Your appointment was cancelled "
                + "by an administrator. "
                + $"Reason: {reason}");

        if (appointment.Therapist.UserId !=
            appointment.Client.UserId)
        {
            await _notificationSender
                .SendToUserAsync(
                    appointment.Therapist.UserId,
                    "Appointment cancelled by administrator",
                    "An appointment was cancelled "
                    + "by an administrator. "
                    + $"Reason: {reason}");
        }
    }
}