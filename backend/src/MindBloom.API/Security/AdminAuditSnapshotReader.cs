using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.API.Security;

public static class AdminAuditSnapshotReader
{
    public static async Task<string?> ReadAsync(
        ApplicationDbContext context,
        string entityType,
        string? entityId,
        HttpContext httpContext,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(entityId) ||
            !int.TryParse(entityId, out var id) ||
            id <= 0)
        {
            return null;
        }

        object? snapshot =
            entityType switch
            {
                "User" =>
                    await ReadUserAsync(
                        context,
                        id,
                        cancellationToken),

                "Therapist" =>
                    await ReadTherapistAsync(
                        context,
                        id,
                        cancellationToken),

                "Review" =>
                    await ReadReviewAsync(
                        context,
                        id,
                        cancellationToken),

                "Appointment" =>
                    await ReadAppointmentAsync(
                        context,
                        id,
                        cancellationToken),

                "Payment" =>
                    await ReadPaymentAsync(
                        context,
                        id,
                        httpContext,
                        cancellationToken),

                "Membership" =>
                    await ReadMembershipAsync(
                        context,
                        id,
                        cancellationToken),

                "MembershipPlan" =>
                    await ReadMembershipPlanAsync(
                        context,
                        id,
                        cancellationToken),

                _ => null
            };

        if (snapshot == null)
        {
            return null;
        }

        return JsonSerializer.Serialize(
            snapshot,
            new JsonSerializerOptions
            {
                PropertyNamingPolicy =
                    JsonNamingPolicy.CamelCase
            });
    }

    private static async Task<object?>
        ReadUserAsync(
            ApplicationDbContext context,
            int userId,
            CancellationToken cancellationToken)
    {
        return await context.Users
            .AsNoTracking()
            .Where(x =>
                x.Id == userId)
            .Select(x =>
                new
                {
                    x.FirstName,
                    x.LastName,
                    x.PhoneNumber,
                    x.DateOfBirth,
                    x.Gender,
                    x.IsActive,
                    x.IsBlocked,
                    x.IsEmailVerified,
                    IsTwoFactorEnabled =
                        x.TwoFactorEnabledCustom
                        || x.TwoFactorEnabled
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static async Task<object?>
        ReadTherapistAsync(
            ApplicationDbContext context,
            int therapistId,
            CancellationToken cancellationToken)
    {
        return await context.Therapists
            .AsNoTracking()
            .Where(x =>
                x.Id == therapistId &&
                !x.IsDeleted)
            .Select(x =>
                new
                {
                    VerificationStatus =
                        x.VerificationStatus
                            .ToString(),

                    x.VerificationNotes,

                    x.Specialization,

                    x.HourlyRate,

                    x.ExperienceYears,

                    x.Education,

                    x.OffersOnline,

                    x.OffersInPerson
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static async Task<object?>
        ReadReviewAsync(
            ApplicationDbContext context,
            int reviewId,
            CancellationToken cancellationToken)
    {
        return await context.Reviews
            .AsNoTracking()
            .Where(x =>
                x.Id == reviewId)
            .Select(x =>
                new
                {
                    x.IsApproved,

                    x.IsDeleted,

                    ModerationStatus =
                        x.ModerationStatus
                            .ToString(),

                    x.ModerationReason,

                    x.ModeratedAtUtc,

                    x.ModeratedByUserId,

                    HasTherapistReply =
                        x.TherapistReply != null
                        &&
                        x.TherapistReply !=
                        string.Empty
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static async Task<object?>
        ReadAppointmentAsync(
            ApplicationDbContext context,
            int appointmentId,
            CancellationToken cancellationToken)
    {
        return await context.Appointments
            .AsNoTracking()
            .Where(x =>
                x.Id == appointmentId &&
                !x.IsDeleted)
            .Select(x =>
                new
                {
                    Status =
                        x.Status.ToString(),

                    x.IsPaid,

                    PaymentStatus =
                        x.Payment == null
                            ? null
                            : x.Payment.Status
                                .ToString(),

                    x.StartUtc,

                    x.EndUtc,

                    Type =
                        x.Type.ToString(),

                    x.Price
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static async Task<object?>
        ReadPaymentAsync(
            ApplicationDbContext context,
            int paymentId,
            HttpContext httpContext,
            CancellationToken cancellationToken)
    {
        var paymentType =
            ResolvePaymentType(
                httpContext);

        if (paymentType.Equals(
                "Membership",
                StringComparison.OrdinalIgnoreCase))
        {
            return await context
                .MembershipPayments
                .AsNoTracking()
                .Where(x =>
                    x.Id == paymentId &&
                    !x.IsDeleted)
                .Select(x =>
                    new
                    {
                        PaymentType =
                            "Membership",

                        x.ClientMembershipId,

                        x.Amount,

                        x.Currency,

                        Status =
                            x.Status.ToString(),

                        x.PaidAtUtc
                    })
                .FirstOrDefaultAsync(
                    cancellationToken);
        }

        return await context.Payments
            .AsNoTracking()
            .Where(x =>
                x.Id == paymentId &&
                !x.IsDeleted)
            .Select(x =>
                new
                {
                    PaymentType =
                        "Appointment",

                    x.AppointmentId,

                    x.Amount,

                    Status =
                        x.Status.ToString(),

                    x.PaidAtUtc,

                    x.RefundReason,

                    x.RefundRequestedAtUtc,

                    x.RefundedAtUtc,

                    x.RefundFailureReason
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static async Task<object?>
        ReadMembershipAsync(
            ApplicationDbContext context,
            int membershipId,
            CancellationToken cancellationToken)
    {
        return await context
            .ClientMemberships
            .AsNoTracking()
            .Where(x =>
                x.Id == membershipId &&
                !x.IsDeleted)
            .Select(x =>
                new
                {
                    x.ClientId,

                    x.TherapistId,

                    PlanType =
                        x.PlanType.ToString(),

                    x.TotalSessions,

                    x.RemainingSessions,

                    x.Price,

                    x.DurationMonths,

                    x.IsActive,

                    x.PurchasedAtUtc,

                    x.ExpiresAtUtc,

                    PaymentStatus =
                        x.Payment == null
                            ? null
                            : x.Payment.Status
                                .ToString()
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static async Task<object?>
        ReadMembershipPlanAsync(
            ApplicationDbContext context,
            int planId,
            CancellationToken cancellationToken)
    {
        return await context.MembershipPlans
            .AsNoTracking()
            .Where(x =>
                x.Id == planId)
            .Select(x =>
                new
                {
                    x.Name,

                    x.Description,

                    PlanType =
                        x.PlanType.ToString(),

                    x.Price,

                    x.DurationMonths,

                    x.IncludedSessions,

                    x.DiscountPercentage,

                    x.BenefitsJson,

                    x.IsActive,

                    x.IsDeleted
                })
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private static string ResolvePaymentType(
        HttpContext context)
    {
        if (context.Request.RouteValues
                .TryGetValue(
                    "paymentType",
                    out var routeValue) &&
            routeValue != null)
        {
            return routeValue
                .ToString()
                ?.Trim()
                ?? "Appointment";
        }

        var segments =
            context.Request.Path.Value
                ?.Split(
                    '/',
                    StringSplitOptions
                        .RemoveEmptyEntries)
            ?? [];

        var paymentsIndex =
            Array.FindIndex(
                segments,
                segment =>
                    segment.Equals(
                        "payments",
                        StringComparison
                            .OrdinalIgnoreCase));

        if (paymentsIndex >= 0 &&
            paymentsIndex + 1 <
            segments.Length)
        {
            var possibleType =
                segments[
                    paymentsIndex + 1];

            if (possibleType.Equals(
                    "Appointment",
                    StringComparison.OrdinalIgnoreCase)
                ||
                possibleType.Equals(
                    "Membership",
                    StringComparison.OrdinalIgnoreCase))
            {
                return possibleType;
            }
        }

        return "Appointment";
    }
}