using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.AdminReports.DTOs;
using MindBloom.Application.Features.AdminReports.Interfaces;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class AdminReportService : IAdminReportService
{
    private readonly ApplicationDbContext _context;

    public AdminReportService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<AppointmentRevenueReportDto>
        GetAppointmentRevenueReportAsync(
            AdminReportPeriodQueryDto query,
            CancellationToken cancellationToken = default)
    {
        ValidatePeriod(query);

        var appointments = await _context.Appointments
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                x.StartUtc >= query.FromUtc &&
                x.StartUtc <= query.ToUtc)
            .Select(x => new AppointmentReportRecord
            {
                AppointmentId = x.Id,
                ClientId = x.ClientId,
                TherapistId = x.TherapistId,
                Status = x.Status,
                IsPaid = x.IsPaid,

                PaymentId =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.Id
                        : null,

                PaymentAmount =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.Amount
                        : 0,

                PaidAtUtc =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.PaidAtUtc
                        : null,

                RefundRequestedAtUtc =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.RefundRequestedAtUtc
                        : null,

                RefundedAtUtc =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.RefundedAtUtc
                        : null,

                RefundFailureReason =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.RefundFailureReason
                        : null
            })
            .ToListAsync(cancellationToken);

        var appointmentsByStatus = appointments
            .GroupBy(x => x.Status)
            .OrderBy(x => x.Key)
            .Select(group => new AppointmentStatusReportItemDto
            {
                Status = group.Key.ToString(),
                Count = group.Count()
            })
            .ToList();

        var paymentRecords = appointments
            .Where(x => x.PaymentId.HasValue)
            .ToList();

        var paidPayments = paymentRecords
            .Where(x => x.PaidAtUtc.HasValue)
            .ToList();

        var refundRequestedPayments = paidPayments
            .Where(x => x.RefundRequestedAtUtc.HasValue)
            .ToList();

        var refundedPayments = paidPayments
            .Where(x => x.RefundedAtUtc.HasValue)
            .ToList();

        var failedRefundPayments = paidPayments
            .Where(x =>
                !string.IsNullOrWhiteSpace(
                    x.RefundFailureReason))
            .ToList();

        var grossRevenue = paidPayments.Sum(
            x => x.PaymentAmount);

        /*
         * Payment trenutno nema posebno RefundAmount polje.
         * Zato se završeni refund računa kao puni povrat
         * originalnog iznosa Payment zapisa.
         */
        var refundedAmount = refundedPayments.Sum(
            x => x.PaymentAmount);

        var netRevenue =
            grossRevenue - refundedAmount;

        return new AppointmentRevenueReportDto
        {
            FromUtc = query.FromUtc,
            ToUtc = query.ToUtc,

            TotalAppointments =
                appointments.Count,

            UniqueClientsCount = appointments
                .Select(x => x.ClientId)
                .Distinct()
                .Count(),

            UniqueTherapistsCount = appointments
                .Select(x => x.TherapistId)
                .Distinct()
                .Count(),

            AppointmentsByStatus =
                appointmentsByStatus,

            PaymentSummary =
                new AppointmentPaymentReportDto
                {
                    TotalPaymentRecords =
                        paymentRecords.Count,

                    PaidPaymentsCount =
                        paidPayments.Count,

                    UnpaidAppointmentsCount =
                        appointments.Count(x =>
                            !x.IsPaid ||
                            !x.PaymentId.HasValue ||
                            !x.PaidAtUtc.HasValue),

                    RefundRequestedCount =
                        refundRequestedPayments.Count,

                    RefundedPaymentsCount =
                        refundedPayments.Count,

                    FailedRefundsCount =
                        failedRefundPayments.Count,

                    GrossRevenue =
                        grossRevenue,

                    RefundedAmount =
                        refundedAmount,

                    NetRevenue =
                        netRevenue
                }
        };
    }

    public async Task<TherapistPerformanceReportDto>
        GetTherapistPerformanceReportAsync(
            AdminReportPeriodQueryDto query,
            CancellationToken cancellationToken = default)
    {
        ValidatePeriod(query);

        var therapists = await _context.Therapists
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted)
            .Select(x => new TherapistReportRecord
            {
                TherapistId = x.Id,
                UserId = x.UserId,
                FirstName = x.User.FirstName,
                LastName = x.User.LastName,
                Specialization = x.Specialization
            })
            .ToListAsync(cancellationToken);

        var appointments = await _context.Appointments
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                !x.Therapist.IsDeleted &&
                x.StartUtc >= query.FromUtc &&
                x.StartUtc <= query.ToUtc)
            .Select(x => new TherapistAppointmentReportRecord
            {
                AppointmentId = x.Id,
                TherapistId = x.TherapistId,
                ClientId = x.ClientId,
                Status = x.Status,

                PaymentId =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.Id
                        : null,

                PaymentAmount =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.Amount
                        : 0,

                PaidAtUtc =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.PaidAtUtc
                        : null,

                RefundedAtUtc =
                    x.Payment != null &&
                    !x.Payment.IsDeleted
                        ? x.Payment.RefundedAtUtc
                        : null
            })
            .ToListAsync(cancellationToken);

        var reviews = await _context.Reviews
            .AsNoTracking()
            .Where(x =>
                !x.IsDeleted &&
                !x.Appointment.IsDeleted &&
                !x.Therapist.IsDeleted &&
                x.Appointment.StartUtc >= query.FromUtc &&
                x.Appointment.StartUtc <= query.ToUtc)
            .Select(x => new TherapistReviewReportRecord
            {
                TherapistId = x.TherapistId,
                AppointmentId = x.AppointmentId,
                Rating = x.Rating
            })
            .ToListAsync(cancellationToken);

        var reportItems =
            new List<TherapistPerformanceReportItemDto>();

        foreach (var therapist in therapists)
        {
            var therapistAppointments = appointments
                .Where(x =>
                    x.TherapistId ==
                    therapist.TherapistId)
                .ToList();

            var completedAppointments =
                therapistAppointments
                    .Where(x =>
                        x.Status ==
                        AppointmentStatus.Completed)
                    .ToList();

            var paidAppointments =
                therapistAppointments
                    .Where(x =>
                        x.PaymentId.HasValue &&
                        x.PaidAtUtc.HasValue)
                    .ToList();

            var refundedAppointments =
                paidAppointments
                    .Where(x =>
                        x.RefundedAtUtc.HasValue)
                    .ToList();

            var therapistReviews = reviews
                .Where(x =>
                    x.TherapistId ==
                    therapist.TherapistId)
                .ToList();

            var grossRevenue =
                paidAppointments.Sum(
                    x => x.PaymentAmount);

            /*
             * Kako Payment nema RefundAmount,
             * svaki završeni refund predstavlja puni povrat.
             */
            var refundedAmount =
                refundedAppointments.Sum(
                    x => x.PaymentAmount);

            var therapistName = BuildFullName(
                therapist.FirstName,
                therapist.LastName,
                therapist.TherapistId);

            reportItems.Add(
                new TherapistPerformanceReportItemDto
                {
                    TherapistId =
                        therapist.TherapistId,

                    UserId =
                        therapist.UserId,

                    TherapistName =
                        therapistName,

                    Specialization =
                        therapist.Specialization,

                    TotalAppointments =
                        therapistAppointments.Count,

                    CompletedAppointments =
                        completedAppointments.Count,

                    UniqueClientsCount =
                        completedAppointments
                            .Select(x => x.ClientId)
                            .Distinct()
                            .Count(),

                    GrossRevenue =
                        grossRevenue,

                    RefundedAmount =
                        refundedAmount,

                    NetRevenue =
                        grossRevenue -
                        refundedAmount,

                    AverageRating =
                        therapistReviews.Count == 0
                            ? null
                            : Math.Round(
                                therapistReviews.Average(
                                    x => (double)x.Rating),
                                2),

                    ReviewCount =
                        therapistReviews.Count
                });
        }

        reportItems = reportItems
            .OrderByDescending(x =>
                x.NetRevenue)
            .ThenByDescending(x =>
                x.CompletedAppointments)
            .ThenBy(x =>
                x.TherapistName)
            .ToList();

        var completedAppointmentsForPeriod =
            appointments
                .Where(x =>
                    x.Status ==
                    AppointmentStatus.Completed)
                .ToList();

        return new TherapistPerformanceReportDto
        {
            FromUtc = query.FromUtc,
            ToUtc = query.ToUtc,

            TherapistCount =
                reportItems.Count,

            TotalCompletedAppointments =
                completedAppointmentsForPeriod.Count,

            TotalUniqueClients =
                completedAppointmentsForPeriod
                    .Select(x => x.ClientId)
                    .Distinct()
                    .Count(),

            TotalGrossRevenue =
                reportItems.Sum(
                    x => x.GrossRevenue),

            TotalRefundedAmount =
                reportItems.Sum(
                    x => x.RefundedAmount),

            TotalNetRevenue =
                reportItems.Sum(
                    x => x.NetRevenue),

            Therapists =
                reportItems
        };
    }

    private static void ValidatePeriod(
        AdminReportPeriodQueryDto query)
    {
        if (query.FromUtc == default)
        {
            throw new ArgumentException(
                "Report start date is required.");
        }

        if (query.ToUtc == default)
        {
            throw new ArgumentException(
                "Report end date is required.");
        }

        if (query.FromUtc > query.ToUtc)
        {
            throw new ArgumentException(
                "Report start date cannot be later than the end date.");
        }

        var maximumPeriod =
            TimeSpan.FromDays(366 * 5);

        if (query.ToUtc - query.FromUtc >
            maximumPeriod)
        {
            throw new ArgumentException(
                "Report period cannot be longer than five years.");
        }
    }

    private static string BuildFullName(
        string? firstName,
        string? lastName,
        int therapistId)
    {
        var fullName = string.Join(
            " ",
            new[]
            {
                firstName?.Trim(),
                lastName?.Trim()
            }
            .Where(x =>
                !string.IsNullOrWhiteSpace(x)));

        return string.IsNullOrWhiteSpace(fullName)
            ? $"Therapist #{therapistId}"
            : fullName;
    }

    private sealed class AppointmentReportRecord
    {
        public int AppointmentId { get; set; }

        public int ClientId { get; set; }

        public int TherapistId { get; set; }

        public AppointmentStatus Status { get; set; }

        public bool IsPaid { get; set; }

        public int? PaymentId { get; set; }

        public decimal PaymentAmount { get; set; }

        public DateTime? PaidAtUtc { get; set; }

        public DateTime? RefundRequestedAtUtc { get; set; }

        public DateTime? RefundedAtUtc { get; set; }

        public string? RefundFailureReason { get; set; }
    }

    private sealed class TherapistReportRecord
    {
        public int TherapistId { get; set; }

        public int UserId { get; set; }

        public string? FirstName { get; set; }

        public string? LastName { get; set; }

        public string Specialization { get; set; } =
            string.Empty;
    }

    private sealed class TherapistAppointmentReportRecord
    {
        public int AppointmentId { get; set; }

        public int TherapistId { get; set; }

        public int ClientId { get; set; }

        public AppointmentStatus Status { get; set; }

        public int? PaymentId { get; set; }

        public decimal PaymentAmount { get; set; }

        public DateTime? PaidAtUtc { get; set; }

        public DateTime? RefundedAtUtc { get; set; }
    }

    private sealed class TherapistReviewReportRecord
    {
        public int TherapistId { get; set; }

        public int AppointmentId { get; set; }

        public int Rating { get; set; }
    }
}