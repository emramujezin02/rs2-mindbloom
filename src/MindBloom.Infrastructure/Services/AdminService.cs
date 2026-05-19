using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly UserManager<ApplicationUser>
        _userManager;

    private readonly ApplicationDbContext
    _context;

    public AdminService(
        UserManager<ApplicationUser>
            userManager, ApplicationDbContext context)
    {
        _userManager = userManager;
        _context = context;
    }

    public async Task<List<UserListDto>>
        GetUsersAsync()
    {
        var users =
            await _userManager.Users
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .ToListAsync();

        var result =
            new List<UserListDto>();

        foreach (var user in users)
        {
            var roles =
                await _userManager
                    .GetRolesAsync(user);

            result.Add(new UserListDto
            {
                Id = user.Id,
                FirstName = user.FirstName,
                LastName = user.LastName,
                Email = user.Email!,
                Role = roles.FirstOrDefault() ?? "No Role",
                IsEmailVerified = user.IsEmailVerified,
                CreatedAtUtc = user.CreatedAtUtc,
                IsBlocked = user.IsBlocked
            });
        }

        return result;
    }

    public async Task UpdateUserStatusAsync(
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

        user.IsBlocked =
            request.IsBlocked;

        await _userManager
            .UpdateAsync(user);
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
                        x.VerificationStatus
                        == TherapistVerificationStatus
                            .Pending),

            ApprovedTherapists =
                await _context.Therapists
                    .CountAsync(x =>
                        x.VerificationStatus
                        == TherapistVerificationStatus
                            .Approved),

            RejectedTherapists =
                await _context.Therapists
                    .CountAsync(x =>
                        x.VerificationStatus
                        == TherapistVerificationStatus
                            .Rejected),

            TotalAppointments =
                await _context.Appointments
                    .CountAsync(),

            CompletedAppointments =
                await _context.Appointments
                    .CountAsync(x =>
                        x.Status
                        == AppointmentStatus
                            .Completed),

            PendingAppointments =
                await _context.Appointments
                    .CountAsync(x =>
                        x.Status
                        == AppointmentStatus
                            .Pending),

            CancelledAppointments =
                await _context.Appointments
                    .CountAsync(x =>
                        x.Status
                        == AppointmentStatus
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
                        x.Status
                        == PaymentStatus.Paid)
                    .SumAsync(x =>
                        (decimal?)x.Amount)
                    ?? 0
        };
    }
}