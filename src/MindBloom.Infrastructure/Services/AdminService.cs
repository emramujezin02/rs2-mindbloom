using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly UserManager<ApplicationUser>
        _userManager;

    private readonly ApplicationDbContext
        _context;

    public AdminService(
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext context)
    {
        _userManager = userManager;
        _context = context;
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
            int therapistId,
            UpdateTherapistVerificationDto request)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        therapist.VerificationStatus =
            request.Status;

        therapist.VerificationNotes =
            request.Notes;

        await _context.SaveChangesAsync();
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
}