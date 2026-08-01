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
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using System.Text.Json;

namespace MindBloom.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ApplicationDbContext _context;
    private readonly INotificationSender _notificationSender;
    private readonly IPaymentService _paymentService;
    private readonly IMembershipService _membershipService;
    private readonly IAuthService _authService;
    private readonly IBusinessNotificationService _businessNotificationService;
    
    public AdminService(
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext context,
        INotificationSender notificationSender,
        IBusinessNotificationService businessNotificationService,
        IPaymentService paymentService,
        IMembershipService membershipService,
        IAuthService authService)
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

        _businessNotificationService =
    businessNotificationService;

        _authService = authService;
    }

    public async Task<PagedResponse<UserListDto>>
        GetUsersAsync(
            SearchAdminUsersDto request)
    {
        var pagination =
    PaginationHelper.Normalize(
        request.PageNumber,
        request.PageSize);

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

        if (request.RegisteredFrom.HasValue)
        {
            query = query.Where(user =>
                user.CreatedAtUtc >=
                request.RegisteredFrom.Value.Date);
        }

        if (request.RegisteredTo.HasValue)
        {
            var exclusiveEndDate =
                request.RegisteredTo.Value.Date.AddDays(1);

            query = query.Where(user =>
                user.CreatedAtUtc < exclusiveEndDate);
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
    pagination.Skip)
.Take(
    pagination.PageSize)
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

        return PagedResponse<UserListDto>
    .Create(
        users,
        pagination.PageNumber,
        pagination.PageSize,
        totalCount);

    }

    public async Task<AdminUserDetailsDto>
    GetUserDetailsAsync(
        int userId)
    {
        var user =
            await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        var role =
            await (
                from userRole in _context.UserRoles

                join identityRole in _context.Roles
                    on userRole.RoleId
                    equals identityRole.Id

                where userRole.UserId == user.Id

                select identityRole.Name
            )
            .FirstOrDefaultAsync();

        var auditHistory =
    await _context.UserAudits
        .AsNoTracking()
        .Include(x =>
            x.ChangedByUser)
        .Where(x =>
            x.TargetUserId == userId)
        .OrderByDescending(x =>
            x.ChangedAtUtc)
        .Take(50)
        .Select(x =>
            new AdminUserAuditDto
            {
                Id = x.Id,
                Action = x.Action,
                ChangedByName =
                    x.ChangedByUser.FirstName
                    + " "
                    + x.ChangedByUser.LastName,
                ChangedByEmail =
                    x.ChangedByUser.Email
                    ?? string.Empty,
                PreviousValues =
                    x.PreviousValues,
                NewValues =
                    x.NewValues,
                Reason = x.Reason,
                ChangedAtUtc =
                    x.ChangedAtUtc
            })
        .ToListAsync();

        return new AdminUserDetailsDto
        {
            Id =
                user.Id,

            FirstName =
                user.FirstName,

            LastName =
                user.LastName,

            FullName =
                (
                    user.FirstName
                    + " "
                    + user.LastName
                )
                .Trim(),

            Email =
                user.Email
                ?? string.Empty,

            PhoneNumber =
                user.PhoneNumber,

            DateOfBirth =
                user.DateOfBirth,

            Gender =
                user.Gender.ToString(),

            Role =
                role
                ?? "No Role",

            ProfileImageUrl =
                user.ProfileImageUrl,

            IsActive =
                user.IsActive,

            IsBlocked =
                user.IsBlocked,

            IsEmailVerified =
                user.IsEmailVerified
                || user.EmailConfirmed,

            IsTwoFactorEnabled =
                user.TwoFactorEnabledCustom
                || user.TwoFactorEnabled,

            CreatedAtUtc =user.CreatedAtUtc,
            LastLoginAtUtc = user.LastLoginAtUtc,
            AuditHistory = auditHistory
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
            throw new NotFoundException(
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

        var previousIsBlocked = user.IsBlocked;
        var previousIsActive = user.IsActive;

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

        var action =
    request.IsBlocked
        ? "AccountBlocked"
        : "AccountUnblocked";

        AddUserAudit(
            targetUserId: user.Id,
            changedByUserId:
                authenticatedAdminUserId,
            action: action,
            previousValues: new
            {
                IsBlocked = previousIsBlocked,
                IsActive = previousIsActive
            },
            newValues: new
            {
                user.IsBlocked,
                user.IsActive
            },
            reason: request.IsBlocked
                ? "User account blocked by administrator."
                : "User account unblocked by administrator.");

        await _context.SaveChangesAsync();
    }

    public async Task
     UpdateTherapistVerificationAsync(
         int authenticatedAdminUserId,
         int therapistId,
         UpdateTherapistVerificationDto request)
    {
        var allowedStatuses =
            new[]
            {
            TherapistVerificationStatus.Approved,
            TherapistVerificationStatus.Rejected,
            TherapistVerificationStatus.RequiresChanges
            };

        if (!allowedStatuses.Contains(
                request.Status))
        {
            throw new BusinessException(
                "Invalid therapist verification decision.");
        }

        var normalizedNotes =
            request.Notes?.Trim();

        if (
            (
                request.Status ==
                TherapistVerificationStatus.Rejected
                ||
                request.Status ==
                TherapistVerificationStatus.RequiresChanges
            )
            &&
            string.IsNullOrWhiteSpace(
                normalizedNotes))
        {
            throw new BusinessException(
                request.Status ==
                TherapistVerificationStatus.Rejected
                    ? "Rejection reason is required."
                    : "Required changes must be described.");
        }

        if (normalizedNotes?.Length > 1000)
        {
            throw new BusinessException(
                "Verification notes may contain at most 1000 characters.");
        }

        var admin =
            await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                    authenticatedAdminUserId);

        if (admin == null)
        {
            throw new NotFoundException(
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
                    &&
                    role.Name ==
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
                .AsNoTracking()
                .Include(x => x.Documents)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId
                    && !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        if (
            request.Status ==
            TherapistVerificationStatus.Approved
            &&
            !therapist.Documents.Any(x =>
                !x.IsDeleted))
        {
            throw new BusinessException(
                "Therapist cannot be approved without uploaded verification documents.");
        }

        await using var transaction =
            await _context.Database
                .BeginTransactionAsync();

        string title;
        string message;

        try
        {
            var affectedRows =
                await _context.Therapists
                    .Where(x =>
                        x.Id == therapistId
                        &&
                        !x.IsDeleted
                        &&
                        x.VerificationStatus ==
                        TherapistVerificationStatus.Pending)
                    .ExecuteUpdateAsync(setters =>
                        setters
                            .SetProperty(
                                x => x.VerificationStatus,
                                request.Status)
                            .SetProperty(
                                x => x.VerificationNotes,
                                normalizedNotes)
                            .SetProperty(
                                x => x.UpdatedAtUtc,
                                DateTime.UtcNow));

            if (affectedRows == 0)
            {
                throw new BusinessException(
                    "This therapist application has already been processed.");
            }

            if (
                request.Status ==
                TherapistVerificationStatus.Approved)
            {
                await _context.TherapistDocuments
                    .Where(x =>
                        x.TherapistId ==
                        therapistId
                        &&
                        !x.IsDeleted)
                    .ExecuteUpdateAsync(setters =>
                        setters.SetProperty(
                            x => x.IsApproved,
                            true));
            }
            else
            {
                await _context.TherapistDocuments
                    .Where(x =>
                        x.TherapistId ==
                        therapistId
                        &&
                        !x.IsDeleted)
                    .ExecuteUpdateAsync(setters =>
                        setters.SetProperty(
                            x => x.IsApproved,
                            false));
            }

            var changedAtUtc =
                DateTime.UtcNow;

            _context
                .TherapistVerificationAudits
                .Add(
                    new TherapistVerificationAudit
                    {
                        TherapistId =
                            therapistId,

                        AdminUserId =
                            authenticatedAdminUserId,

                        PreviousStatus =
                            TherapistVerificationStatus.Pending,

                        NewStatus =
                            request.Status,

                        Notes =
                            normalizedNotes,

                        ChangedAtUtc =
                            changedAtUtc
                    });

            title =
                request.Status switch
                {
                    TherapistVerificationStatus.Approved =>
                        "Therapist profile approved",

                    TherapistVerificationStatus.Rejected =>
                        "Therapist profile rejected",

                    TherapistVerificationStatus.RequiresChanges =>
                        "Therapist profile requires changes",

                    _ =>
                        "Therapist verification updated"
                };

             message =
                request.Status switch
                {
                    TherapistVerificationStatus.Approved =>
                        "Your therapist profile has been verified and approved.",

                    TherapistVerificationStatus.Rejected =>
                        "Your therapist profile verification was rejected. "
                        + $"Reason: {normalizedNotes}",

                    TherapistVerificationStatus.RequiresChanges =>
                        "Your therapist verification application requires changes. "
                        + $"Required changes: {normalizedNotes}",

                    _ =>
                        "Your therapist verification status was updated."
                };

            _context.Notifications.Add(
                new Notification
                {
                    UserId =
                        therapist.UserId,

                    ActionType =
                        NotificationActionType
                            .TherapistProfile,

                    ResourceId =
                        therapistId,

                    Title =
                        title,

                    Message =
                        message,

                    IsRead =
                        false,

                    SentAtUtc =
                        changedAtUtc
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
        therapist.UserId,
        title,
        message);
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
        var pagination =
    PaginationHelper.Normalize(
        request.PageNumber,
        request.PageSize);

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

        if (request.IsApproved.HasValue)
        {
            query = query.Where(x =>
                x.IsApproved ==
                request.IsApproved.Value);
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
    pagination.Skip)
.Take(
    pagination.PageSize)
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

                        IsApproved = x.IsApproved,

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        ModeratedAtUtc =
                            x.ModeratedAtUtc
                    })
                .ToListAsync();

        return PagedResponse<AdminReviewListDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<
    PagedResponse<TherapistVerificationListDto>>
    GetPendingTherapistsAsync(
        SearchTherapistVerificationDto request)
    {
        var pagination =
            PaginationHelper.Normalize(
                request.PageNumber,
                request.PageSize);

        var query =
            _context.Therapists
                .AsNoTracking()
                .Include(x => x.User)
                .Where(x => !x.IsDeleted)
                .AsQueryable();

        if (request.Status.HasValue)
        {
            query = query.Where(x =>
                x.VerificationStatus ==
                request.Status.Value);
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
                    x.User.FirstName
                    + " "
                    + x.User.LastName
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.User.Email
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Specialization
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                (
                    x.Education
                    ?? string.Empty
                )
                .ToLower()
                .Contains(search));
        }

        var totalCount =
            await query.CountAsync();

        var items =
            await query
                .OrderBy(x =>
                    x.VerificationStatus ==
                    TherapistVerificationStatus.Pending
                        ? 0
                        : 1)
                .ThenBy(x =>
                    x.CreatedAtUtc)
                .Skip(pagination.Skip)
                .Take(pagination.PageSize)
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

        return PagedResponse<
                TherapistVerificationListDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
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
                    x.TherapyApproaches)
                    .ThenInclude(x =>
                        x.TherapyApproach)
                .Include(x =>
                    x.VerificationAudits)
                    .ThenInclude(x =>
                        x.AdminUser)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId
                    && !x.IsDeleted);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var latestDecision =
    therapist.VerificationAudits
        .OrderByDescending(x =>
            x.ChangedAtUtc)
        .FirstOrDefault();

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

            Education =
    therapist.Education,

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

            DecisionAtUtc =
    latestDecision?.ChangedAtUtc,

            DecisionByAdminName =
    latestDecision == null
        ? null
        : (
            latestDecision
                .AdminUser.FirstName
            + " "
            + latestDecision
                .AdminUser.LastName
        ).Trim(),

            TherapyApproaches =
    therapist.TherapyApproaches
        .Where(x =>
            !x.IsDeleted
            && !x.TherapyApproach.IsDeleted)
        .OrderBy(x =>
            x.TherapyApproach.Name)
        .Select(x =>
            new TherapistVerificationApproachDto
            {
                Id =
                    x.TherapyApproachId,

                Name =
                    x.TherapyApproach.Name,

                Description =
                    x.TherapyApproach.Description
            })
        .ToList(),

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
            throw new NotFoundException(
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

            IsApproved = review.IsApproved,

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

    public async Task ApproveReviewAsync(
    int authenticatedAdminUserId,
    int reviewId)
    {
        var admin =
            await _context.Users
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        authenticatedAdminUserId &&
                    !x.IsBlocked &&
                    x.IsActive);

        if (admin == null)
        {
            throw new NotFoundException(
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
            throw new NotFoundException(
                "Review not found.");
        }

        if (review.IsDeleted)
        {
            throw new Exception(
                "A deleted review cannot be approved.");
        }

        if (review.IsApproved)
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
            review.IsApproved =
                true;

            review.ModeratedByUserId =
                authenticatedAdminUserId;

            review.ModeratedAtUtc =
                now;

            review.ModerationReason =
                "Approved for public display.";

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
                            .Approved,

                    Reason =
                        "Approved for public display.",

                    PerformedAtUtc =
                        now
                };

            _context
                .ReviewModerationAudits
                .Add(audit);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();

            throw;
        }

        await _businessNotificationService
            .PublishAsync(
                review.Client.UserId,
                "Review approved",
                "Your review has been approved "
                + "for public display.",
                actionType:
                    NotificationActionType.Review,
                resourceId:
                    review.Id);
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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
            review.IsDeleted = true;

            review.IsApproved = false;

            review.ModerationReason = reason;

            review.ModeratedByUserId = authenticatedAdminUserId;

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

                    ActionType =
    NotificationActionType.Review,

                    ResourceId =
    review.Id,

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
            throw new NotFoundException(
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
            throw new BadRequestException(
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
            throw new NotFoundException(
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
            throw new NotFoundException(
                "Appointment not found.");
        }

        if (appointment.Status ==
            AppointmentStatus.Cancelled)
        {
            throw new BusinessException(
                "Appointment has already been cancelled.");
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

        var previousStatus = appointment.Status;

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

                ActionType =
    NotificationActionType.Appointment,

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

    ActionType =
        NotificationActionType.Appointment,

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

    public async Task<
     PagedResponse<AdminPaymentListDto>>
     GetPaymentsAsync(
         SearchAdminPaymentsDto request)
    {
        if (
            request.DateFromUtc.HasValue
            &&
            request.DateToUtc.HasValue
            &&
            request.DateFromUtc.Value >
            request.DateToUtc.Value)
        {
            throw new BadRequestException(
                "Start date cannot be later than end date.");
        }

        if (
            request.MinimumAmount.HasValue
            &&
            request.MinimumAmount.Value < 0)
        {
            throw new BadRequestException(
                "Minimum amount cannot be negative.");
        }

        if (
            request.MaximumAmount.HasValue
            &&
            request.MaximumAmount.Value < 0)
        {
            throw new BadRequestException(
                "Maximum amount cannot be negative.");
        }

        if (
            request.MinimumAmount.HasValue
            &&
            request.MaximumAmount.HasValue
            &&
            request.MinimumAmount.Value >
            request.MaximumAmount.Value)
        {
            throw new BadRequestException(
                "Minimum amount cannot be greater than maximum amount.");
        }

        var normalizedPaymentType =
            request.PaymentType?
                .Trim();

        if (
            !string.IsNullOrWhiteSpace(
                normalizedPaymentType)
            &&
            !normalizedPaymentType.Equals(
                "Appointment",
                StringComparison.OrdinalIgnoreCase)
            &&
            !normalizedPaymentType.Equals(
                "Membership",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new BadRequestException(
                "Payment type must be Appointment or Membership.");
        }

        var appointmentPayments =
            _context.Payments
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted)
                .AsQueryable();

        var membershipPayments =
            _context.MembershipPayments
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(
                request.Search))
        {
            var search =
                request.Search
                    .Trim()
                    .ToLower();

            appointmentPayments =
                appointmentPayments.Where(x =>
                    x.Id.ToString()
                        .Contains(search)
                    ||
                    x.AppointmentId.ToString()
                        .Contains(search)
                    ||
                    x.StripePaymentIntentId
                        .ToLower()
                        .Contains(search)
                    ||
                    (
                        x.StripeRefundId
                        ?? string.Empty
                    )
                    .ToLower()
                    .Contains(search)
                    ||
                    (
                        x.Appointment.Client.User.FirstName
                        + " "
                        + x.Appointment.Client.User.LastName
                    )
                    .ToLower()
                    .Contains(search)
                    ||
                    (
                        x.Appointment.Client.User.Email
                        ?? string.Empty
                    )
                    .ToLower()
                    .Contains(search)
                    ||
                    (
                        x.Appointment.Therapist.User.FirstName
                        + " "
                        + x.Appointment.Therapist.User.LastName
                    )
                    .ToLower()
                    .Contains(search));

            membershipPayments =
                membershipPayments.Where(x =>
                    x.Id.ToString()
                        .Contains(search)
                    ||
                    x.ClientMembershipId.ToString()
                        .Contains(search)
                    ||
                    x.StripePaymentIntentId
                        .ToLower()
                        .Contains(search)
                    ||
                    (
                        x.ClientMembership.Client.User.FirstName
                        + " "
                        + x.ClientMembership.Client.User.LastName
                    )
                    .ToLower()
                    .Contains(search)
                    ||
                    (
                        x.ClientMembership.Client.User.Email
                        ?? string.Empty
                    )
                    .ToLower()
                    .Contains(search)
                    ||
                    (
                        x.ClientMembership.Therapist.User.FirstName
                        + " "
                        + x.ClientMembership.Therapist.User.LastName
                    )
                    .ToLower()
                    .Contains(search));
        }

        if (request.Status.HasValue)
        {
            appointmentPayments =
                appointmentPayments.Where(x =>
                    x.Status ==
                    request.Status.Value);

            membershipPayments =
                membershipPayments.Where(x =>
                    x.Status ==
                    request.Status.Value);
        }

        if (request.DateFromUtc.HasValue)
        {
            appointmentPayments =
                appointmentPayments.Where(x =>
                    x.CreatedAtUtc >=
                    request.DateFromUtc.Value);

            membershipPayments =
                membershipPayments.Where(x =>
                    x.CreatedAtUtc >=
                    request.DateFromUtc.Value);
        }

        if (request.DateToUtc.HasValue)
        {
            var exclusiveEnd =
                request.DateToUtc.Value
                    .Date
                    .AddDays(1);

            appointmentPayments =
                appointmentPayments.Where(x =>
                    x.CreatedAtUtc <
                    exclusiveEnd);

            membershipPayments =
                membershipPayments.Where(x =>
                    x.CreatedAtUtc <
                    exclusiveEnd);
        }

        if (request.MinimumAmount.HasValue)
        {
            appointmentPayments =
                appointmentPayments.Where(x =>
                    x.Amount >=
                    request.MinimumAmount.Value);

            membershipPayments =
                membershipPayments.Where(x =>
                    x.Amount >=
                    request.MinimumAmount.Value);
        }

        if (request.MaximumAmount.HasValue)
        {
            appointmentPayments =
                appointmentPayments.Where(x =>
                    x.Amount <=
                    request.MaximumAmount.Value);

            membershipPayments =
                membershipPayments.Where(x =>
                    x.Amount <=
                    request.MaximumAmount.Value);
        }

        var appointmentProjection =
            appointmentPayments.Select(x =>
                new AdminPaymentListDto
                {
                    Id =
                        x.Id,

                    PaymentType =
                        "Appointment",

                    AppointmentId =
                        x.AppointmentId,

                    MembershipId =
                        null,

                    ClientName =
                        x.Appointment.Client.User.FirstName
                        + " "
                        + x.Appointment.Client.User.LastName,

                    ClientEmail =
                        x.Appointment.Client.User.Email
                        ?? string.Empty,

                    TherapistName =
                        x.Appointment.Therapist.User.FirstName
                        + " "
                        + x.Appointment.Therapist.User.LastName,

                    Amount =
                        x.Amount,

                    Currency =
                        "USD",

                    Status =
                        x.Status.ToString(),

                    Purpose =
                        "Therapy appointment",

                    CreatedAtUtc =
                        x.CreatedAtUtc,

                    PaidAtUtc =
                        x.PaidAtUtc,

                    RefundedAtUtc =
                        x.RefundedAtUtc,

                    CanRefund =
                        x.Status ==
                        PaymentStatus.Paid
                        ||
                        x.Status ==
                        PaymentStatus.RefundFailed,

                    RefundUnavailableReason =
                        x.Status ==
                            PaymentStatus.Refunded
                            ? "This payment has already been refunded."
                            : x.Status ==
                                PaymentStatus.RefundPending
                                ? "A refund is already being processed."
                                : x.Status !=
                                        PaymentStatus.Paid
                                    &&
                                    x.Status !=
                                        PaymentStatus.RefundFailed
                                    ? "This payment is not in a refundable state."
                                    : null
                });

        var membershipProjection =
            membershipPayments.Select(x =>
                new AdminPaymentListDto
                {
                    Id =
                        x.Id,

                    PaymentType =
                        "Membership",

                    AppointmentId =
                        null,

                    MembershipId =
                        x.ClientMembershipId,

                    ClientName =
                        x.ClientMembership.Client.User.FirstName
                        + " "
                        + x.ClientMembership.Client.User.LastName,

                    ClientEmail =
                        x.ClientMembership.Client.User.Email
                        ?? string.Empty,

                    TherapistName =
                        x.ClientMembership.Therapist.User.FirstName
                        + " "
                        + x.ClientMembership.Therapist.User.LastName,

                    Amount =
                        x.Amount,

                    Currency =
                        x.Currency.ToUpper(),

                    Status =
                        x.Status.ToString(),

                    Purpose =
                        x.ClientMembership.PlanType ==
                            MembershipPlanType.TenSessions
                            ? "Ten-session membership"
                            : x.ClientMembership.PlanType ==
                                MembershipPlanType.TwentySessions
                                ? "Twenty-session membership"
                                : "Thirty-session membership",

                    CreatedAtUtc =
                        x.CreatedAtUtc,

                    PaidAtUtc =
                        x.PaidAtUtc,

                    RefundedAtUtc =
                        null,

                    CanRefund =
                        false,

                    RefundUnavailableReason =
                        "Membership payment refunds are not currently supported."
                });

        IQueryable<AdminPaymentListDto>
            combinedQuery;

        if (
            normalizedPaymentType?.Equals(
                "Appointment",
                StringComparison.OrdinalIgnoreCase)
            == true)
        {
            combinedQuery =
                appointmentProjection;
        }
        else if (
            normalizedPaymentType?.Equals(
                "Membership",
                StringComparison.OrdinalIgnoreCase)
            == true)
        {
            combinedQuery =
                membershipProjection;
        }
        else
        {
            combinedQuery =
                appointmentProjection.Concat(
                    membershipProjection);
        }

        var totalCount =
            await combinedQuery.CountAsync();

        var pagination =
            PaginationHelper.Normalize(
                request.PageNumber,
                request.PageSize);

        var items =
            await combinedQuery
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(pagination.Skip)
                .Take(pagination.PageSize)
                .ToListAsync();

        return PagedResponse<
                AdminPaymentListDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<AdminPaymentDetailsDto>
     GetPaymentDetailsAsync(
         string paymentType,
         int paymentId)
    {
        var normalizedPaymentType =
            paymentType?
                .Trim();

        if (normalizedPaymentType.Equals(
                "Appointment",
                StringComparison.OrdinalIgnoreCase))
        {
            var payment =
                await _context.Payments
                    .AsNoTracking()
                    .Include(x => x.Appointment)
                        .ThenInclude(x => x.Client)
                            .ThenInclude(x => x.User)
                    .Include(x => x.Appointment)
                        .ThenInclude(x => x.Therapist)
                            .ThenInclude(x => x.User)
                    .FirstOrDefaultAsync(x =>
                        x.Id == paymentId
                        &&
                        !x.IsDeleted);

            if (payment == null)
            {
                throw new NotFoundException(
                    "Appointment payment not found.");
            }

            return new AdminPaymentDetailsDto
            {
                Id =
                    payment.Id,

                PaymentType =
                    "Appointment",

                AppointmentId =
                    payment.AppointmentId,

                MembershipId =
                    null,

                ClientId =
                    payment.Appointment.ClientId,

                ClientUserId =
                    payment.Appointment.Client.UserId,

                ClientName =
                    payment.Appointment.Client.User.FirstName
                    + " "
                    + payment.Appointment.Client.User.LastName,

                ClientEmail =
                    payment.Appointment.Client.User.Email
                    ?? string.Empty,

                TherapistId =
                    payment.Appointment.TherapistId,

                TherapistName =
                    payment.Appointment.Therapist.User.FirstName
                    + " "
                    + payment.Appointment.Therapist.User.LastName,

                TherapistEmail =
                    payment.Appointment.Therapist.User.Email
                    ?? string.Empty,

                Amount =
                    payment.Amount,

                Currency =
                    "USD",

                Status =
                    payment.Status.ToString(),

                Purpose =
                    "Therapy appointment",

                StripePaymentIntentId =
                    payment.StripePaymentIntentId,

                CreatedAtUtc =
                    payment.CreatedAtUtc,

                PaidAtUtc =
                    payment.PaidAtUtc,

                StripeRefundId =
                    payment.StripeRefundId,

                RefundReason =
                    payment.RefundReason,

                RefundRequestedAtUtc =
                    payment.RefundRequestedAtUtc,

                RefundedAtUtc =
                    payment.RefundedAtUtc,

                RefundFailureReason =
                    payment.RefundFailureReason,

                AppointmentStatus =
                    payment.Appointment.Status
                        .ToString(),

                AppointmentStartUtc =
                    payment.Appointment.StartUtc,

                AppointmentEndUtc =
                    payment.Appointment.EndUtc,

                AppointmentType =
                    payment.Appointment.Type
                        .ToString(),

                AppointmentIsPaid =
                    payment.Appointment.IsPaid,

                MembershipPlanType =
                    null,

                TotalSessions =
                    null,

                RemainingSessions =
                    null,

                MembershipIsActive =
                    null,

                MembershipExpiresAtUtc =
                    null,

                CanRefund =
                    payment.Status ==
                        PaymentStatus.Paid
                    ||
                    payment.Status ==
                        PaymentStatus.RefundFailed,

                RefundUnavailableReason =
                    payment.Status ==
                        PaymentStatus.Refunded
                        ? "This payment has already been refunded."
                        : payment.Status ==
                            PaymentStatus.RefundPending
                            ? "A refund is already being processed."
                            : payment.Status !=
                                    PaymentStatus.Paid
                                &&
                                payment.Status !=
                                    PaymentStatus.RefundFailed
                                ? "This payment is not in a refundable state."
                                : null
            };
        }

        if (normalizedPaymentType.Equals(
                "Membership",
                StringComparison.OrdinalIgnoreCase))
        {
            var payment =
                await _context.MembershipPayments
                    .AsNoTracking()
                    .Include(x => x.ClientMembership)
                        .ThenInclude(x => x.Client)
                            .ThenInclude(x => x.User)
                    .Include(x => x.ClientMembership)
                        .ThenInclude(x => x.Therapist)
                            .ThenInclude(x => x.User)
                    .FirstOrDefaultAsync(x =>
                        x.Id == paymentId
                        &&
                        !x.IsDeleted);

            if (payment == null)
            {
                throw new NotFoundException(
                    "Membership payment not found.");
            }

            var membership =
                payment.ClientMembership;

            return new AdminPaymentDetailsDto
            {
                Id =
                    payment.Id,

                PaymentType =
                    "Membership",

                AppointmentId =
                    null,

                MembershipId =
                    membership.Id,

                ClientId =
                    membership.ClientId,

                ClientUserId =
                    membership.Client.UserId,

                ClientName =
                    membership.Client.User.FirstName
                    + " "
                    + membership.Client.User.LastName,

                ClientEmail =
                    membership.Client.User.Email
                    ?? string.Empty,

                TherapistId =
                    membership.TherapistId,

                TherapistName =
                    membership.Therapist.User.FirstName
                    + " "
                    + membership.Therapist.User.LastName,

                TherapistEmail =
                    membership.Therapist.User.Email
                    ?? string.Empty,

                Amount =
                    payment.Amount,

                Currency =
                    payment.Currency.ToUpperInvariant(),

                Status =
                    payment.Status.ToString(),

                Purpose =
                    membership.PlanType switch
                    {
                        MembershipPlanType.TenSessions =>
                            "Ten-session membership",

                        MembershipPlanType.TwentySessions =>
                            "Twenty-session membership",

                        MembershipPlanType.ThirtySessions =>
                            "Thirty-session membership",

                        _ =>
                            "Therapy membership"
                    },

                StripePaymentIntentId =
                    payment.StripePaymentIntentId,

                CreatedAtUtc =
                    payment.CreatedAtUtc,

                PaidAtUtc =
                    payment.PaidAtUtc,

                StripeRefundId =
                    null,

                RefundReason =
                    null,

                RefundRequestedAtUtc =
                    null,

                RefundedAtUtc =
                    null,

                RefundFailureReason =
                    null,

                AppointmentStatus =
                    null,

                AppointmentStartUtc =
                    null,

                AppointmentEndUtc =
                    null,

                AppointmentType =
                    null,

                AppointmentIsPaid =
                    null,

                MembershipPlanType =
                    membership.PlanType
                        .ToString(),

                TotalSessions =
                    membership.TotalSessions,

                RemainingSessions =
                    membership.RemainingSessions,

                MembershipIsActive =
                    membership.IsActive,

                MembershipExpiresAtUtc =
                    membership.ExpiresAtUtc,

                CanRefund =
                    false,

                RefundUnavailableReason =
                    "Membership payment refunds are not currently supported."
            };
        }

        throw new BadRequestException(
            "Payment type must be Appointment or Membership.");
    }

    public async Task<AdminPaymentReceiptDto>
    GetPaymentReceiptAsync(
        string paymentType,
        int paymentId)
    {
        var normalizedPaymentType =
            paymentType?
                .Trim();

        if (normalizedPaymentType.Equals(
                "Appointment",
                StringComparison.OrdinalIgnoreCase))
        {
            var payment =
                await _context.Payments
                    .AsNoTracking()
                    .Include(x => x.Appointment)
                        .ThenInclude(x => x.Client)
                            .ThenInclude(x => x.User)
                    .Include(x => x.Appointment)
                        .ThenInclude(x => x.Therapist)
                            .ThenInclude(x => x.User)
                    .FirstOrDefaultAsync(x =>
                        x.Id == paymentId
                        &&
                        !x.IsDeleted);

            if (payment == null)
            {
                throw new NotFoundException(
                    "Appointment payment not found.");
            }

            return new AdminPaymentReceiptDto
            {
                InvoiceNumber =
                    $"APT-INV-{payment.Id:D6}",

                PaymentId =
                    payment.Id,

                PaymentType =
                    "Appointment",

                AppointmentId =
                    payment.AppointmentId,

                MembershipId =
                    null,

                ClientName =
                    payment.Appointment.Client.User.FirstName
                    + " "
                    + payment.Appointment.Client.User.LastName,

                ClientEmail =
                    payment.Appointment.Client.User.Email
                    ?? string.Empty,

                TherapistName =
                    payment.Appointment.Therapist.User.FirstName
                    + " "
                    + payment.Appointment.Therapist.User.LastName,

                Amount =
                    payment.Amount,

                Currency =
                    "USD",

                Status =
                    payment.Status.ToString(),

                Purpose =
                    "Therapy appointment",

                PaymentDateUtc =
                    payment.PaidAtUtc
                    ?? payment.CreatedAtUtc,

                AppointmentStartUtc =
                    payment.Appointment.StartUtc,

                AppointmentEndUtc =
                    payment.Appointment.EndUtc,

                StripePaymentIntentId =
                    payment.StripePaymentIntentId,

                StripeRefundId =
                    payment.StripeRefundId,

                RefundReason =
                    payment.RefundReason,

                RefundedAtUtc =
                    payment.RefundedAtUtc
            };
        }

        if (normalizedPaymentType.Equals(
                "Membership",
                StringComparison.OrdinalIgnoreCase))
        {
            var payment =
                await _context.MembershipPayments
                    .AsNoTracking()
                    .Include(x => x.ClientMembership)
                        .ThenInclude(x => x.Client)
                            .ThenInclude(x => x.User)
                    .Include(x => x.ClientMembership)
                        .ThenInclude(x => x.Therapist)
                            .ThenInclude(x => x.User)
                    .FirstOrDefaultAsync(x =>
                        x.Id == paymentId
                        &&
                        !x.IsDeleted);

            if (payment == null)
            {
                throw new NotFoundException(
                    "Membership payment not found.");
            }

            var membership =
                payment.ClientMembership;

            return new AdminPaymentReceiptDto
            {
                InvoiceNumber =
                    $"MEM-INV-{payment.Id:D6}",

                PaymentId =
                    payment.Id,

                PaymentType =
                    "Membership",

                AppointmentId =
                    null,

                MembershipId =
                    membership.Id,

                ClientName =
                    membership.Client.User.FirstName
                    + " "
                    + membership.Client.User.LastName,

                ClientEmail =
                    membership.Client.User.Email
                    ?? string.Empty,

                TherapistName =
                    membership.Therapist.User.FirstName
                    + " "
                    + membership.Therapist.User.LastName,

                Amount =
                    payment.Amount,

                Currency =
                    payment.Currency.ToUpperInvariant(),

                Status =
                    payment.Status.ToString(),

                Purpose =
                    membership.PlanType switch
                    {
                        MembershipPlanType.TenSessions =>
                            "Ten-session membership",

                        MembershipPlanType.TwentySessions =>
                            "Twenty-session membership",

                        MembershipPlanType.ThirtySessions =>
                            "Thirty-session membership",

                        _ =>
                            "Therapy membership"
                    },

                PaymentDateUtc =
                    payment.PaidAtUtc
                    ?? payment.CreatedAtUtc,

                AppointmentStartUtc =
                    null,

                AppointmentEndUtc =
                    null,

                StripePaymentIntentId =
                    payment.StripePaymentIntentId,

                StripeRefundId =
                    null,

                RefundReason =
                    null,

                RefundedAtUtc =
                    null
            };
        }

        throw new BadRequestException(
            "Payment type must be Appointment or Membership.");
    }

    public async Task RefundPaymentAsync(
     int authenticatedAdminUserId,
     string paymentType,
     int paymentId,
     AdminRefundPaymentDto request)
    {
        var normalizedReason =
            request.Reason?.Trim()
            ?? string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedReason))
        {
            throw new BadRequestException(
                "Refund reason is required.");
        }

        if (normalizedReason.Length < 5)
        {
            throw new BadRequestException(
                "Refund reason must contain at least 5 characters.");
        }

        if (normalizedReason.Length > 500)
        {
            throw new BadRequestException(
                "Refund reason may contain at most 500 characters.");
        }

        var normalizedPaymentType =
            paymentType?
                .Trim();

        if (normalizedPaymentType.Equals(
                "Membership",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new BusinessException(
                "Membership payment refunds are not currently supported.");
        }

        if (!normalizedPaymentType.Equals(
                "Appointment",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new BadRequestException(
                "Payment type must be Appointment or Membership.");
        }

        var admin =
            await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        authenticatedAdminUserId
                    &&
                    !x.IsBlocked
                    &&
                    x.IsActive);

        if (admin == null)
        {
            throw new NotFoundException(
                "Administrator not found.");
        }

        var payment =
            await _context.Payments
                .AsNoTracking()
                .Include(x => x.Appointment)
                    .ThenInclude(x => x.Client)
                .FirstOrDefaultAsync(x =>
                    x.Id == paymentId
                    &&
                    !x.IsDeleted);

        if (payment == null)
        {
            throw new NotFoundException(
                "Appointment payment not found.");
        }

        if (payment.Status ==
            PaymentStatus.Refunded)
        {
            throw new BusinessException(
                "This payment has already been refunded.");
        }

        if (payment.Status ==
            PaymentStatus.RefundPending)
        {
            throw new BusinessException(
                "A refund for this payment is already being processed.");
        }

        if (
            payment.Status !=
                PaymentStatus.Paid
            &&
            payment.Status !=
                PaymentStatus.RefundFailed)
        {
            throw new BusinessException(
                "Only a paid payment or a failed refund may be refunded.");
        }

        var previousStatus =
            payment.Status;

        var completeReason =
            $"Admin {admin.FirstName} "
            + $"{admin.LastName}: "
            + normalizedReason;

        try
        {
            await _paymentService
                .RefundAppointmentPaymentAsync(
                    payment.Appointment.Client.UserId,
                    payment.AppointmentId,
                    completeReason);

            var currentStatus =
                await _context.Payments
                    .AsNoTracking()
                    .Where(x =>
                        x.Id == paymentId)
                    .Select(x =>
                        x.Status)
                    .FirstAsync();

            _context.PaymentAdminAudits.Add(
                new PaymentAdminAudit
                {
                    AdminUserId =
                        authenticatedAdminUserId,

                    PaymentType =
                        "Appointment",

                    PaymentId =
                        paymentId,

                    PreviousStatus =
                        previousStatus,

                    NewStatus =
                        currentStatus,

                    Action =
                        "FullRefundRequested",

                    Reason =
                        normalizedReason,

                    PerformedAtUtc =
                        DateTime.UtcNow
                });

            await _context.SaveChangesAsync();
        }
        catch (Exception exception)
        {
            var currentStatus =
                await _context.Payments
                    .AsNoTracking()
                    .Where(x =>
                        x.Id == paymentId)
                    .Select(x =>
                        x.Status)
                    .FirstOrDefaultAsync();

            _context.PaymentAdminAudits.Add(
                new PaymentAdminAudit
                {
                    AdminUserId =
                        authenticatedAdminUserId,

                    PaymentType =
                        "Appointment",

                    PaymentId =
                        paymentId,

                    PreviousStatus =
                        previousStatus,

                    NewStatus =
                        currentStatus == 0
                            ? previousStatus
                            : currentStatus,

                    Action =
                        "FullRefundFailed",

                    Reason =
                        normalizedReason
                        + " | Provider error: "
                        + exception.Message,

                    PerformedAtUtc =
                        DateTime.UtcNow
                });

            await _context.SaveChangesAsync();

            throw;
        }
    }

    public async Task<
    PagedResponse<AdminMembershipListDto>>
    GetMembershipsAsync(
        SearchAdminMembershipsDto request)
    {
        var query =
            _context.ClientMemberships
                .AsNoTracking()
                .Include(x =>
                    x.Client)
                    .ThenInclude(x =>
                        x.User)
                .Include(x =>
                    x.Therapist)
                    .ThenInclude(x =>
                        x.User)
                .Include(x =>
                    x.Payment)
                .Include(x =>
                    x.Usages)
                .Where(x =>
                    !x.IsDeleted)
                .AsQueryable();

        if (!string.IsNullOrWhiteSpace(
                request.Search))
        {
            var search =
                request.Search
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                x.Id.ToString()
                    .Contains(search)
                ||
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
                .Contains(search));
        }

        if (request.ClientId.HasValue)
        {
            query = query.Where(x =>
                x.ClientId ==
                request.ClientId.Value);
        }

        if (request.TherapistId.HasValue)
        {
            query = query.Where(x =>
                x.TherapistId ==
                request.TherapistId.Value);
        }

        if (request.PlanType.HasValue)
        {
            query = query.Where(x =>
                x.PlanType ==
                request.PlanType.Value);
        }

        if (request.ExpiresFromUtc.HasValue
    &&
    request.ExpiresToUtc.HasValue
    &&
    request.ExpiresFromUtc.Value >
    request.ExpiresToUtc.Value)
        {
            throw new BadRequestException(
                "Expiration start date cannot be later than expiration end date.");
        }

        if (request.ExpiresFromUtc.HasValue)
        {
            query = query.Where(x =>
                x.ExpiresAtUtc != null
                &&
                x.ExpiresAtUtc >=
                    request.ExpiresFromUtc.Value);
        }

        if (request.ExpiresToUtc.HasValue)
        {
            var exclusiveEnd =
                request.ExpiresToUtc.Value
                    .Date
                    .AddDays(1);

            query = query.Where(x =>
                x.ExpiresAtUtc != null
                &&
                x.ExpiresAtUtc <
                    exclusiveEnd);
        }

        if (request.PaymentStatus.HasValue)
        {
            query = query.Where(x =>
                x.Payment != null
                && x.Payment.Status ==
                    request.PaymentStatus.Value);
        }

        if (!string.IsNullOrWhiteSpace(
                request.MembershipStatus))
        {
            var membershipStatus =
                request.MembershipStatus
                    .Trim()
                    .ToLower();

            var now =
                DateTime.UtcNow;

            query = membershipStatus switch
            {
                "active" =>
                    query.Where(x =>
                        x.IsActive
                        && x.RemainingSessions > 0
                        && x.Payment != null
                        && x.Payment.Status ==
                            PaymentStatus.Paid
                        && (
                            x.ExpiresAtUtc == null
                            || x.ExpiresAtUtc > now
                        )),

                "inactive" =>
                    query.Where(x =>
                        !x.IsActive),

                "pendingpayment" =>
                    query.Where(x =>
                        x.Payment == null
                        || x.Payment.Status ==
                            PaymentStatus.Pending),

                "expired" =>
                    query.Where(x =>
                        x.ExpiresAtUtc != null
                        && x.ExpiresAtUtc <= now),

                "depleted" =>
                    query.Where(x =>
                        x.RemainingSessions <= 0
                        && x.Payment != null
                        && x.Payment.Status ==
                            PaymentStatus.Paid),

                _ =>
                    throw new Exception(
                        "Invalid membership status filter.")
            };
        }

        var totalCount =
            await query.CountAsync();

        var nowUtc =
            DateTime.UtcNow;

        var rawItems =
            await query
                .OrderByDescending(x =>
                    x.PurchasedAtUtc
                    ?? x.CreatedAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    (request.PageNumber - 1)
                    * request.PageSize)
                .Take(request.PageSize)
                .Select(x =>
                    new
                    {
                        x.Id,

                        x.ClientId,

                        ClientName =
                            x.Client.User.FirstName
                            + " "
                            + x.Client.User.LastName,

                        ClientEmail =
                            x.Client.User.Email
                            ?? string.Empty,

                        x.TherapistId,

                        TherapistName =
                            x.Therapist.User.FirstName
                            + " "
                            + x.Therapist.User.LastName,

                        TherapistEmail =
                            x.Therapist.User.Email
                            ?? string.Empty,

                        PlanType =
                            x.PlanType.ToString(),

                        x.TotalSessions,

                        x.RemainingSessions,

                        x.Price,

                        x.IsActive,

                        PaymentStatus =
                            x.Payment == null
                                ? "NotCreated"
                                : x.Payment.Status
                                    .ToString(),

                        PaymentIsPaid =
                            x.Payment != null
                            && x.Payment.Status ==
                                PaymentStatus.Paid,

                        x.PurchasedAtUtc,

                        x.ExpiresAtUtc,

                        x.CreatedAtUtc,

                        ReservedSessions =
                            x.Usages.Count(usage =>
                                usage.Status ==
                                MembershipUsageStatus
                                    .Reserved),

                        ConsumedSessions =
                            x.Usages.Count(usage =>
                                usage.Status ==
                                MembershipUsageStatus
                                    .Consumed),

                        RestoredSessions =
                            x.Usages.Count(usage =>
                                usage.Status ==
                                MembershipUsageStatus
                                    .Restored)
                    })
                .ToListAsync();

        var items =
            rawItems
                .Select(x =>
                    new AdminMembershipListDto
                    {
                        Id =
                            x.Id,

                        ClientId =
                            x.ClientId,

                        ClientName =
                            x.ClientName,

                        ClientEmail =
                            x.ClientEmail,

                        TherapistId =
                            x.TherapistId,

                        TherapistName =
                            x.TherapistName,

                        TherapistEmail =
                            x.TherapistEmail,

                        PlanType =
                            x.PlanType,

                        MembershipStatus =
                            GetAdminMembershipStatus(
                                x.IsActive,
                                x.RemainingSessions,
                                x.PaymentStatus,
                                x.ExpiresAtUtc,
                                nowUtc),

                        TotalSessions =
                            x.TotalSessions,

                        RemainingSessions =
                            x.RemainingSessions,

                        UsedSessions =
                            x.ConsumedSessions,

                        ReservedSessions =
                            x.ReservedSessions,

                        ConsumedSessions =
                            x.ConsumedSessions,

                        RestoredSessions =
                            x.RestoredSessions,

                        Price =
                            x.Price,

                        IsActive =
                            x.IsActive,

                        PaymentStatus =
                            x.PaymentStatus,

                        PurchasedAtUtc =
                            x.PurchasedAtUtc,

                        ExpiresAtUtc =
                            x.ExpiresAtUtc,

                        CreatedAtUtc =
                            x.CreatedAtUtc
                    })
                .ToList();

        return new PagedResponse<
            AdminMembershipListDto>
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
                        totalCount
                        / (double)request.PageSize)
        };
    }

    public async Task<AdminMembershipDetailsDto>
        GetMembershipDetailsAsync(
            int membershipId)
    {
        var membership =
            await _context.ClientMemberships
                .AsNoTracking()
                .Include(x =>
                    x.Client)
                    .ThenInclude(x =>
                        x.User)
                .Include(x =>
                    x.Therapist)
                    .ThenInclude(x =>
                        x.User)
                .Include(x =>
                    x.Payment)
                .Include(x =>
                    x.Usages)
                    .ThenInclude(x =>
                        x.Appointment)
                .FirstOrDefaultAsync(x =>
                    x.Id == membershipId
                    && !x.IsDeleted);

        if (membership == null)
        {
            throw new NotFoundException(
                "Membership not found.");
        }

        var reservedSessions =
            membership.Usages.Count(x =>
                x.Status ==
                MembershipUsageStatus.Reserved);

        var consumedSessions =
            membership.Usages.Count(x =>
                x.Status ==
                MembershipUsageStatus.Consumed);

        var restoredSessions =
            membership.Usages.Count(x =>
                x.Status ==
                MembershipUsageStatus.Restored);

        var paymentStatus =
            membership.Payment == null
                ? "NotCreated"
                : membership.Payment.Status
                    .ToString();

        return new AdminMembershipDetailsDto
        {
            Id =
                membership.Id,

            ClientId =
                membership.ClientId,

            ClientUserId =
                membership.Client.UserId,

            ClientName =
                membership.Client.User.FirstName
                + " "
                + membership.Client.User.LastName,

            ClientEmail =
                membership.Client.User.Email
                ?? string.Empty,

            TherapistId =
                membership.TherapistId,

            TherapistUserId =
                membership.Therapist.UserId,

            TherapistName =
                membership.Therapist.User.FirstName
                + " "
                + membership.Therapist.User.LastName,

            TherapistEmail =
                membership.Therapist.User.Email
                ?? string.Empty,

            PlanType =
                membership.PlanType.ToString(),

            MembershipStatus =
                GetAdminMembershipStatus(
                    membership.IsActive,
                    membership.RemainingSessions,
                    paymentStatus,
                    membership.ExpiresAtUtc,
                    DateTime.UtcNow),

            TotalSessions =
                membership.TotalSessions,

            RemainingSessions =
                membership.RemainingSessions,

            UsedSessions =
                consumedSessions,

            ReservedSessions =
                reservedSessions,

            ConsumedSessions =
                consumedSessions,

            RestoredSessions =
                restoredSessions,

            Price =
                membership.Price,

            IsActive =
                membership.IsActive,

            PurchasedAtUtc =
                membership.PurchasedAtUtc,

            ExpiresAtUtc =
                membership.ExpiresAtUtc,

            CreatedAtUtc =
                membership.CreatedAtUtc,

            UpdatedAtUtc =
                membership.UpdatedAtUtc,

            Payment =
                membership.Payment == null
                    ? null
                    : new AdminMembershipPaymentDto
                    {
                        Id =
                            membership.Payment.Id,

                        Amount =
                            membership.Payment.Amount,

                        Currency =
                            membership.Payment.Currency,

                        Status =
                            membership.Payment.Status
                                .ToString(),

                        StripePaymentIntentId =
                            membership.Payment
                                .StripePaymentIntentId,

                        PaidAtUtc =
                            membership.Payment
                                .PaidAtUtc,

                        CreatedAtUtc =
                            membership.Payment
                                .CreatedAtUtc
                    },

            Usages =
                membership.Usages
                    .OrderByDescending(x =>
                        x.ReservedAtUtc
                        ?? x.UsedAtUtc)
                    .ThenByDescending(x =>
                        x.Id)
                    .Select(x =>
                        new AdminMembershipUsageDto
                        {
                            Id =
                                x.Id,

                            AppointmentId =
                                x.AppointmentId,

                            AppointmentStatus =
                                x.Appointment.Status
                                    .ToString(),

                            AppointmentStartUtc =
                                x.Appointment.StartUtc,

                            AppointmentEndUtc =
                                x.Appointment.EndUtc,

                            Status =
                                x.Status.ToString(),

                            UsedAtUtc =
                                x.UsedAtUtc,

                            ReservedAtUtc =
                                x.ReservedAtUtc,

                            ConsumedAtUtc =
                                x.ConsumedAtUtc,

                            RestoredAtUtc =
                                x.RestoredAtUtc,

                            ResolutionReason =
                                x.ResolutionReason,

                            CreatedAtUtc =
                                x.CreatedAtUtc,

                            UpdatedAtUtc =
                                x.UpdatedAtUtc
                        })
                    .ToList()
        };
    }

    private static string
        GetAdminMembershipStatus(
            bool isActive,
            int remainingSessions,
            string paymentStatus,
            DateTime? expiresAtUtc,
            DateTime nowUtc)
    {
        if (string.Equals(
                paymentStatus,
                PaymentStatus.Pending.ToString(),
                StringComparison.OrdinalIgnoreCase)
            || string.Equals(
                paymentStatus,
                "NotCreated",
                StringComparison.OrdinalIgnoreCase))
        {
            return "PendingPayment";
        }

        if (expiresAtUtc.HasValue
            && expiresAtUtc.Value <= nowUtc)
        {
            return "Expired";
        }

        if (remainingSessions <= 0
            && string.Equals(
                paymentStatus,
                PaymentStatus.Paid.ToString(),
                StringComparison.OrdinalIgnoreCase))
        {
            return "Depleted";
        }

        if (isActive
            && remainingSessions > 0
            && string.Equals(
                paymentStatus,
                PaymentStatus.Paid.ToString(),
                StringComparison.OrdinalIgnoreCase))
        {
            return "Active";
        }

        return "Inactive";
    }

    public async Task SendPasswordResetAsync(
        int authenticatedAdminUserId,
        int userId)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        if (string.IsNullOrWhiteSpace(
                user.Email))
        {
            throw new BusinessException(
                "User does not have a valid email address.");
        }

        await _authService.ForgotPasswordAsync(
            new ForgotPasswordDto
            {
                Email = user.Email
            });

        AddUserAudit(
            targetUserId: user.Id,
            changedByUserId:
                authenticatedAdminUserId,
            action: "PasswordResetRequested",
            newValues: new
            {
                ResetEmailSent = true
            },
            reason:
                "Password reset email requested by administrator.");

        await _context.SaveChangesAsync();
    }

    public async Task UpdateUserAsync(
     int authenticatedAdminUserId,
     int userId,
     UpdateAdminUserDto request)
    {
        var authenticatedAdminExists =
            await _userManager.Users
                .AnyAsync(x =>
                    x.Id == authenticatedAdminUserId);

        if (!authenticatedAdminExists)
        {
            throw new NotFoundException(
                "Authenticated administrator was not found.");
        }

        var user =
            await _userManager.FindByIdAsync(
                userId.ToString());

        if (user == null)
        {
            throw new NotFoundException(
                "User not found.");
        }

        var firstName =
            request.FirstName?.Trim()
            ?? string.Empty;

        var lastName =
            request.LastName?.Trim()
            ?? string.Empty;

        var phoneNumber =
            string.IsNullOrWhiteSpace(
                request.PhoneNumber)
                ? null
                : request.PhoneNumber.Trim();

        var gender =
            string.IsNullOrWhiteSpace(
                request.Gender)
                ? null
                : request.Gender.Trim();

        if (string.IsNullOrWhiteSpace(firstName))
        {
            throw new BusinessException(
                "First name is required.");
        }

        if (string.IsNullOrWhiteSpace(lastName))
        {
            throw new BusinessException(
                "Last name is required.");
        }

        if (firstName.Length > 100)
        {
            throw new BusinessException(
                "First name may contain at most 100 characters.");
        }

        if (lastName.Length > 100)
        {
            throw new BusinessException(
                "Last name may contain at most 100 characters.");
        }

        if (phoneNumber != null &&
            phoneNumber.Length > 30)
        {
            throw new BusinessException(
                "Phone number may contain at most 30 characters.");
        }

        if (request.DateOfBirth.Date >=
            DateTime.UtcNow.Date)
        {
            throw new BusinessException(
                "Date of birth must be in the past.");
        }

        var allowedGenders =
            new HashSet<string>(
                StringComparer.OrdinalIgnoreCase)
            {
            "Male",
            "Female",
            "Other"
            };

        if (gender != null &&
            !allowedGenders.Contains(gender))
        {
            throw new BusinessException(
                "Gender must be Male, Female or Other.");
        }

        var previousValues = new
        {
            user.FirstName,
            user.LastName,
            user.PhoneNumber,
            user.DateOfBirth,
            user.Gender
        };

        user.FirstName = firstName;
        user.LastName = lastName;
        user.PhoneNumber = phoneNumber;
        user.DateOfBirth = request.DateOfBirth.Date;
        user.Gender = gender;

        var updateResult =
            await _userManager.UpdateAsync(user);

        if (!updateResult.Succeeded)
        {
            throw new BusinessException(
                string.Join(
                    ", ",
                    updateResult.Errors.Select(
                        x => x.Description)));
        }

        AddUserAudit(
            targetUserId: user.Id,
            changedByUserId:
                authenticatedAdminUserId,
            action: "BasicDataUpdated",
            previousValues: previousValues,
            newValues: new
            {
                user.FirstName,
                user.LastName,
                user.PhoneNumber,
                user.DateOfBirth,
                user.Gender
            },
            reason:
                "Basic user information updated by administrator.");

        await _context.SaveChangesAsync();
    }

    private void AddUserAudit(
    int targetUserId,
    int changedByUserId,
    string action,
    object? previousValues = null,
    object? newValues = null,
    string? reason = null)
    {
        _context.UserAudits.Add(
            new UserAudit
            {
                TargetUserId = targetUserId,
                ChangedByUserId = changedByUserId,
                Action = action,
                PreviousValues = previousValues == null
                    ? null
                    : JsonSerializer.Serialize(
                        previousValues),
                NewValues = newValues == null
                    ? null
                    : JsonSerializer.Serialize(
                        newValues),
                Reason = string.IsNullOrWhiteSpace(reason)
                    ? null
                    : reason.Trim(),
                ChangedAtUtc = DateTime.UtcNow
            });
    }

    public async Task<List<AdminMembershipPlanDto>>
    GetMembershipPlansAsync()
    {
        var plans =
            await _context.MembershipPlans
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted)
                .OrderBy(x =>
                    x.IncludedSessions)
                .ThenBy(x =>
                    x.Name)
                .ToListAsync();

        return plans
            .Select(MapAdminMembershipPlan)
            .ToList();
    }

    public async Task<AdminMembershipPlanDto>
    GetMembershipPlanAsync(
        int planId)
    {
        var plan =
            await _context.MembershipPlans
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.Id == planId
                    && !x.IsDeleted);

        if (plan == null)
        {
            throw new NotFoundException(
                "Membership plan not found.");
        }

        return MapAdminMembershipPlan(
            plan);
    }

    public async Task<int>
    CreateMembershipPlanAsync(
        int authenticatedAdminUserId,
        CreateMembershipPlanDto request)
    {
        ValidateMembershipPlan(
            request.Name,
            request.Description,
            request.Price,
            request.DurationMonths,
            request.IncludedSessions,
            request.DiscountPercentage,
            request.Benefits);

        await EnsureActiveAdminAsync(
            authenticatedAdminUserId);

        if (!Enum.IsDefined(
                typeof(MembershipPlanType),
                request.PlanType))
        {
            throw new BadRequestException(
                "Invalid membership plan type.");
        }

        var existingPlan =
            await _context.MembershipPlans
                .FirstOrDefaultAsync(x =>
                    x.PlanType ==
                        request.PlanType
                    && !x.IsDeleted);

        if (existingPlan != null)
        {
            throw new BusinessException(
                "A membership plan with this type already exists.");
        }

        var normalizedBenefits =
            NormalizeBenefits(
                request.Benefits);

        var plan =
            new MembershipPlan
            {
                PlanType =
                    request.PlanType,

                Name =
                    request.Name.Trim(),

                Description =
                    request.Description.Trim(),

                Price =
                    request.Price,

                DurationMonths =
                    request.DurationMonths,

                IncludedSessions =
                    request.IncludedSessions,

                DiscountPercentage =
                    request.DiscountPercentage,

                BenefitsJson =
                    JsonSerializer.Serialize(
                        normalizedBenefits),

                IsActive =
                    request.IsActive
            };

        _context.MembershipPlans.Add(
            plan);

        await _context.SaveChangesAsync();

        AddMembershipPlanAudit(
            plan.Id,
            authenticatedAdminUserId,
            "Created",
            previousValues: null,
            newValues: new
            {
                plan.PlanType,
                plan.Name,
                plan.Description,
                plan.Price,
                plan.DurationMonths,
                plan.IncludedSessions,
                plan.DiscountPercentage,
                Benefits = normalizedBenefits,
                plan.IsActive
            },
            reason:
                "Membership plan created by administrator.");

        await _context.SaveChangesAsync();

        return plan.Id;
    }

    public async Task
    UpdateMembershipPlanAsync(
        int authenticatedAdminUserId,
        int planId,
        UpdateMembershipPlanDto request)
    {
        ValidateMembershipPlan(
            request.Name,
            request.Description,
            request.Price,
            request.DurationMonths,
            request.IncludedSessions,
            request.DiscountPercentage,
            request.Benefits);

        await EnsureActiveAdminAsync(
            authenticatedAdminUserId);

        var plan =
            await _context.MembershipPlans
                .FirstOrDefaultAsync(x =>
                    x.Id == planId
                    && !x.IsDeleted);

        if (plan == null)
        {
            throw new NotFoundException(
                "Membership plan not found.");
        }

        var previousBenefits =
            DeserializeAdminBenefits(
                plan.BenefitsJson);

        var previousValues =
            new
            {
                plan.Name,
                plan.Description,
                plan.Price,
                plan.DurationMonths,
                plan.IncludedSessions,
                plan.DiscountPercentage,
                Benefits =
                    previousBenefits,
                plan.IsActive
            };

        var normalizedBenefits =
            NormalizeBenefits(
                request.Benefits);

        plan.Name =
            request.Name.Trim();

        plan.Description =
            request.Description.Trim();

        plan.Price =
            request.Price;

        plan.DurationMonths =
            request.DurationMonths;

        plan.IncludedSessions =
            request.IncludedSessions;

        plan.DiscountPercentage =
            request.DiscountPercentage;

        plan.BenefitsJson =
            JsonSerializer.Serialize(
                normalizedBenefits);

        AddMembershipPlanAudit(
            plan.Id,
            authenticatedAdminUserId,
            "Updated",
            previousValues,
            new
            {
                plan.Name,
                plan.Description,
                plan.Price,
                plan.DurationMonths,
                plan.IncludedSessions,
                plan.DiscountPercentage,
                Benefits =
                    normalizedBenefits,
                plan.IsActive
            },
            "Membership plan updated by administrator.");

        await _context.SaveChangesAsync();
    }

    public async Task
    UpdateMembershipPlanStatusAsync(
        int authenticatedAdminUserId,
        int planId,
        UpdateMembershipPlanStatusDto request)
    {
        await EnsureActiveAdminAsync(
            authenticatedAdminUserId);

        var plan =
            await _context.MembershipPlans
                .FirstOrDefaultAsync(x =>
                    x.Id == planId
                    && !x.IsDeleted);

        if (plan == null)
        {
            throw new NotFoundException(
                "Membership plan not found.");
        }

        if (plan.IsActive ==
            request.IsActive)
        {
            return;
        }

        var previousStatus =
            plan.IsActive;

        plan.IsActive =
            request.IsActive;

        AddMembershipPlanAudit(
            plan.Id,
            authenticatedAdminUserId,
            request.IsActive
                ? "Activated"
                : "Deactivated",
            new
            {
                IsActive =
                    previousStatus
            },
            new
            {
                plan.IsActive
            },
            string.IsNullOrWhiteSpace(
                request.Reason)
                ? request.IsActive
                    ? "Membership plan activated by administrator."
                    : "Membership plan deactivated by administrator."
                : request.Reason.Trim());

        await _context.SaveChangesAsync();
    }

    public async Task
    DeleteMembershipPlanAsync(
        int authenticatedAdminUserId,
        int planId)
    {
        await EnsureActiveAdminAsync(
            authenticatedAdminUserId);

        var plan =
            await _context.MembershipPlans
                .FirstOrDefaultAsync(x =>
                    x.Id == planId
                    && !x.IsDeleted);

        if (plan == null)
        {
            throw new NotFoundException(
                "Membership plan not found.");
        }

        var hasBeenUsed =
            await _context.ClientMemberships
                .AsNoTracking()
                .AnyAsync(x =>
                    x.PlanType ==
                        plan.PlanType);

        if (hasBeenUsed)
        {
            if (!plan.IsActive)
            {
                return;
            }

            plan.IsActive =
                false;

            AddMembershipPlanAudit(
                plan.Id,
                authenticatedAdminUserId,
                "DeactivatedBecauseUsed",
                new
                {
                    IsActive = true
                },
                new
                {
                    IsActive = false
                },
                "Used membership plans cannot be deleted and were deactivated instead.");

            await _context.SaveChangesAsync();

            return;
        }

        plan.IsActive =
            false;

        plan.IsDeleted =
            true;

        AddMembershipPlanAudit(
            plan.Id,
            authenticatedAdminUserId,
            "SoftDeleted",
            new
            {
                IsActive = true,
                IsDeleted = false
            },
            new
            {
                IsActive = false,
                IsDeleted = true
            },
            "Unused membership plan soft-deleted by administrator.");

        await _context.SaveChangesAsync();
    }

    public async Task<
    List<AdminMembershipPlanAuditDto>>
    GetMembershipPlanHistoryAsync(
        int planId)
    {
        var exists =
            await _context.MembershipPlans
                .AsNoTracking()
                .AnyAsync(x =>
                    x.Id == planId);

        if (!exists)
        {
            throw new NotFoundException(
                "Membership plan not found.");
        }

        return await _context
            .MembershipPlanAudits
            .AsNoTracking()
            .Include(x =>
                x.ChangedByUser)
            .Where(x =>
                x.MembershipPlanId ==
                    planId)
            .OrderByDescending(x =>
                x.ChangedAtUtc)
            .ThenByDescending(x =>
                x.Id)
            .Select(x =>
                new AdminMembershipPlanAuditDto
                {
                    Id =
                        x.Id,

                    Action =
                        x.Action,

                    ChangedByName =
                        x.ChangedByUser
                            .FirstName
                        + " "
                        + x.ChangedByUser
                            .LastName,

                    PreviousValues =
                        x.PreviousValues,

                    NewValues =
                        x.NewValues,

                    Reason =
                        x.Reason,

                    ChangedAtUtc =
                        x.ChangedAtUtc
                })
            .ToListAsync();
    }

    private async Task EnsureActiveAdminAsync(
    int authenticatedAdminUserId)
    {
        var adminExists =
            await _context.Users
                .AsNoTracking()
                .AnyAsync(x =>
                    x.Id ==
                        authenticatedAdminUserId
                    && x.IsActive
                    && !x.IsBlocked);

        if (!adminExists)
        {
            throw new NotFoundException(
                "Administrator not found.");
        }
    }

    private static void ValidateMembershipPlan(
        string? name,
        string? description,
        decimal price,
        int durationMonths,
        int includedSessions,
        decimal discountPercentage,
        List<string>? benefits)
    {
        if (string.IsNullOrWhiteSpace(
                name))
        {
            throw new BadRequestException(
                "Membership plan name is required.");
        }

        if (name.Trim().Length > 150)
        {
            throw new BadRequestException(
                "Membership plan name may contain at most 150 characters.");
        }

        if (string.IsNullOrWhiteSpace(
                description))
        {
            throw new BadRequestException(
                "Membership plan description is required.");
        }

        if (description.Trim().Length >
            1000)
        {
            throw new BadRequestException(
                "Membership plan description may contain at most 1000 characters.");
        }

        if (price < 0)
        {
            throw new BadRequestException(
                "Membership plan price cannot be negative.");
        }

        if (price == 0)
        {
            throw new BadRequestException(
                "Membership plan price must be greater than zero.");
        }

        if (durationMonths <= 0)
        {
            throw new BadRequestException(
                "Membership duration must be greater than zero.");
        }

        if (includedSessions <= 0)
        {
            throw new BadRequestException(
                "Number of included sessions must be greater than zero.");
        }

        if (discountPercentage < 0
            ||
            discountPercentage > 100)
        {
            throw new BadRequestException(
                "Discount percentage must be between 0 and 100.");
        }

        if (benefits != null
            &&
            benefits.Any(x =>
                x != null
                &&
                x.Trim().Length > 300))
        {
            throw new BadRequestException(
                "A membership benefit may contain at most 300 characters.");
        }
    }

    private static List<string> NormalizeBenefits(
        List<string>? benefits)
    {
        return benefits?
            .Where(x =>
                !string.IsNullOrWhiteSpace(x))
            .Select(x =>
                x.Trim())
            .Distinct(
                StringComparer.OrdinalIgnoreCase)
            .ToList()
            ?? [];
    }

    private static List<string>
        DeserializeAdminBenefits(
            string? value)
    {
        if (string.IsNullOrWhiteSpace(
                value))
        {
            return [];
        }

        try
        {
            return JsonSerializer
                .Deserialize<List<string>>(
                    value)
                ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private static AdminMembershipPlanDto
        MapAdminMembershipPlan(
            MembershipPlan plan)
    {
        return new AdminMembershipPlanDto
        {
            Id =
                plan.Id,

            PlanType =
                plan.PlanType,

            Name =
                plan.Name,

            Description =
                plan.Description,

            Price =
                plan.Price,

            DurationMonths =
                plan.DurationMonths,

            IncludedSessions =
                plan.IncludedSessions,

            DiscountPercentage =
                plan.DiscountPercentage,

            Benefits =
                DeserializeAdminBenefits(
                    plan.BenefitsJson),

            IsActive =
                plan.IsActive,

            IsDeleted =
                plan.IsDeleted,

            CreatedAtUtc =
                plan.CreatedAtUtc,

            UpdatedAtUtc =
                plan.UpdatedAtUtc
        };
    }

    private void AddMembershipPlanAudit(
        int membershipPlanId,
        int changedByUserId,
        string action,
        object? previousValues,
        object? newValues,
        string? reason)
    {
        _context.MembershipPlanAudits.Add(
            new MembershipPlanAudit
            {
                MembershipPlanId =
                    membershipPlanId,

                ChangedByUserId =
                    changedByUserId,

                Action =
                    action,

                PreviousValues =
                    previousValues == null
                        ? null
                        : JsonSerializer
                            .Serialize(
                                previousValues),

                NewValues =
                    newValues == null
                        ? null
                        : JsonSerializer
                            .Serialize(
                                newValues),

                Reason =
                    reason,

                ChangedAtUtc =
                    DateTime.UtcNow
            });
    }
}