using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Persistence.Queries;

internal static class DashboardFinancialQueries
{
    // A requested or failed refund has not returned the charged amount to the customer.
    private static readonly PaymentStatus[] RetainedStatuses =
        [PaymentStatus.Paid, PaymentStatus.RefundPending, PaymentStatus.RefundFailed];

    private static IQueryable<Payment> DirectPayments(ApplicationDbContext db) => db.Payments.AsNoTracking()
        .Where(p => !p.IsDeleted && RetainedStatuses.Contains(p.Status));

    public static IQueryable<Payment> TherapistDirectReceipts(ApplicationDbContext db, int therapistId) =>
        DirectPayments(db).Where(p => p.Appointment.TherapistId == therapistId);

    public static async Task<decimal> ClientTotalSpentAsync(ApplicationDbContext db, int clientId)
    {
        var memberships = db.MembershipPayments.AsNoTracking()
            .Where(p => !p.IsDeleted && p.ClientMembership.ClientId == clientId && RetainedStatuses.Contains(p.Status));
        // Direct charges use USD. Do not silently add another currency to a single-currency total.
        if (await memberships.AnyAsync(p => p.Currency == null || p.Currency.ToLower() != "usd"))
            throw new BusinessException("Dashboard totals cannot combine payments in different currencies.");

        var direct = await DirectPayments(db).Where(p => p.Appointment.ClientId == clientId)
            .SumAsync(p => (decimal?)p.Amount) ?? 0;
        var membershipPurchases = await memberships.SumAsync(p => (decimal?)p.Amount) ?? 0;
        return direct + membershipPurchases;
    }
}
