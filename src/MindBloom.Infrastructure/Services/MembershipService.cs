using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class MembershipService : IMembershipService
{
    private readonly ApplicationDbContext _context;

    public MembershipService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<MembershipPlanDto>>
        GetPlansForTherapistAsync(
            int therapistId)
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

        var sessionPrice =
            therapist.HourlyRate;

        return new List<MembershipPlanDto>
        {
            CreatePlan(
                MembershipPlanType.TenSessions,
                "10 sessions package",
                10,
                1,
                sessionPrice),

            CreatePlan(
                MembershipPlanType.TwentySessions,
                "20 sessions package",
                20,
                2,
                sessionPrice),

            CreatePlan(
                MembershipPlanType.ThirtySessions,
                "30 sessions package",
                30,
                3,
                sessionPrice)
        };
    }

    public async Task<MembershipResponseDto>
        PurchaseAsync(
            int clientUserId,
            PurchaseMembershipDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var therapist =
            await _context.Therapists
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == request.TherapistId);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        var activeMembershipExists =
            await _context.ClientMemberships
                .AnyAsync(x =>
                    x.ClientId == client.Id
                    && x.TherapistId
                        == request.TherapistId
                    && x.IsActive
                    && x.RemainingSessions > 0);

        if (activeMembershipExists)
        {
            throw new Exception(
                "You already have an active membership for this therapist.");
        }

        var plan =
            CreatePlan(
                request.PlanType,
                GetPlanName(request.PlanType),
                GetTotalSessions(request.PlanType),
                GetFreeSessions(request.PlanType),
                therapist.HourlyRate);

        var membership =
            new ClientMembership
            {
                ClientId = client.Id,
                TherapistId = therapist.Id,
                PlanType = request.PlanType,
                TotalSessions = plan.TotalSessions,
                RemainingSessions = plan.TotalSessions,
                Price = plan.Price,
                IsActive = true,
                PurchasedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc =
                    DateTime.UtcNow.AddMonths(6)
            };

        _context.ClientMemberships.Add(
            membership);

        await _context.SaveChangesAsync();

        return MapMembership(
            membership,
            therapist);
    }

    public async Task<List<MembershipResponseDto>>
        GetMyMembershipsAsync(
            int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        return await _context.ClientMemberships
            .Include(x => x.Therapist)
                .ThenInclude(x => x.User)
            .Where(x =>
                x.ClientId == client.Id)
            .OrderByDescending(x =>
                x.PurchasedAtUtc)
            .Select(x =>
                new MembershipResponseDto
                {
                    Id = x.Id,
                    TherapistId = x.TherapistId,
                    TherapistName =
                        x.Therapist.User.FirstName
                        + " "
                        + x.Therapist.User.LastName,
                    PlanType =
                        x.PlanType.ToString(),
                    TotalSessions =
                        x.TotalSessions,
                    RemainingSessions =
                        x.RemainingSessions,
                    Price = x.Price,
                    IsActive = x.IsActive,
                    PurchasedAtUtc =
                        x.PurchasedAtUtc,
                    ExpiresAtUtc =
                        x.ExpiresAtUtc
                })
            .ToListAsync();
    }

    public async Task UseMembershipAsync(
        int clientUserId,
        UseMembershipDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId
                    && x.ClientId == client.Id);

        if (appointment == null)
        {
            throw new Exception(
                "Appointment not found.");
        }

        if (appointment.Status
            != AppointmentStatus.Accepted)
        {
            throw new Exception(
                "Membership can only be used for accepted appointments.");
        }

        var alreadyUsed =
            await _context.MembershipUsages
                .AnyAsync(x =>
                    x.AppointmentId
                    == appointment.Id);

        if (alreadyUsed)
        {
            throw new Exception(
                "Membership already used for this appointment.");
        }

        var membership =
            await _context.ClientMemberships
                .FirstOrDefaultAsync(x =>
                    x.ClientId == client.Id
                    && x.TherapistId
                        == appointment.TherapistId
                    && x.IsActive
                    && x.RemainingSessions > 0
                    && (x.ExpiresAtUtc == null
                        || x.ExpiresAtUtc
                            > DateTime.UtcNow));

        if (membership == null)
        {
            throw new Exception(
                "No active membership available for this therapist.");
        }

        membership.RemainingSessions--;

        if (membership.RemainingSessions == 0)
        {
            membership.IsActive = false;
        }

        var usage =
            new MembershipUsage
            {
                ClientMembershipId =
                    membership.Id,
                AppointmentId =
                    appointment.Id,
                UsedAtUtc =
                    DateTime.UtcNow
            };

        _context.MembershipUsages.Add(
            usage);

        await _context.SaveChangesAsync();
    }

    private static MembershipPlanDto CreatePlan(
        MembershipPlanType planType,
        string name,
        int totalSessions,
        int freeSessions,
        decimal sessionPrice)
    {
        var paidSessions =
            totalSessions - freeSessions;

        var price =
            paidSessions * sessionPrice;

        return new MembershipPlanDto
        {
            PlanType = planType,
            Name = name,
            TotalSessions =
                totalSessions,
            FreeSessions =
                freeSessions,
            Price = price,
            PricePerSession =
                totalSessions == 0
                    ? 0
                    : price / totalSessions
        };
    }

    private static int GetTotalSessions(
        MembershipPlanType planType)
    {
        return planType switch
        {
            MembershipPlanType.TenSessions => 10,
            MembershipPlanType.TwentySessions => 20,
            MembershipPlanType.ThirtySessions => 30,
            _ => throw new Exception(
                "Invalid membership plan.")
        };
    }

    private static int GetFreeSessions(
        MembershipPlanType planType)
    {
        return planType switch
        {
            MembershipPlanType.TenSessions => 1,
            MembershipPlanType.TwentySessions => 2,
            MembershipPlanType.ThirtySessions => 3,
            _ => throw new Exception(
                "Invalid membership plan.")
        };
    }

    private static string GetPlanName(
        MembershipPlanType planType)
    {
        return planType switch
        {
            MembershipPlanType.TenSessions =>
                "10 sessions package",
            MembershipPlanType.TwentySessions =>
                "20 sessions package",
            MembershipPlanType.ThirtySessions =>
                "30 sessions package",
            _ => "Membership package"
        };
    }

    private static MembershipResponseDto
        MapMembership(
            ClientMembership membership,
            Therapist therapist)
    {
        return new MembershipResponseDto
        {
            Id = membership.Id,
            TherapistId =
                membership.TherapistId,
            TherapistName =
                therapist.User.FirstName
                + " "
                + therapist.User.LastName,
            PlanType =
                membership.PlanType.ToString(),
            TotalSessions =
                membership.TotalSessions,
            RemainingSessions =
                membership.RemainingSessions,
            Price = membership.Price,
            IsActive =
                membership.IsActive,
            PurchasedAtUtc =
                membership.PurchasedAtUtc,
            ExpiresAtUtc =
                membership.ExpiresAtUtc
        };
    }
}