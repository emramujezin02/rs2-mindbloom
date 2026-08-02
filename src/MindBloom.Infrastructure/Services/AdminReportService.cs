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

    public async Task<AdminDashboardReportDto>
    GetDashboardReportAsync(
        AdminDashboardReportQueryDto query,
        CancellationToken cancellationToken = default)
    {
        ValidateDashboardPeriod(query);

        var nowUtc =
            DateTime.UtcNow;

        var todayStartUtc =
            nowUtc.Date;

        var tomorrowStartUtc =
            todayStartUtc.AddDays(1);

        var currentMonthStartUtc =
            new DateTime(
                nowUtc.Year,
                nowUtc.Month,
                1,
                0,
                0,
                0,
                DateTimeKind.Utc);

        var nextMonthStartUtc =
            currentMonthStartUtc.AddMonths(1);

        var periodEndExclusive =
            query.ToUtc == DateTime.MaxValue
                ? query.ToUtc
                : query.ToUtc.AddTicks(1);

        var totalUsers =
            await _context.Users
                .AsNoTracking()
                .CountAsync(
                    cancellationToken);

        var activeClients =
            await _context.Clients
                .AsNoTracking()
                .CountAsync(
                    client =>
                        !client.IsDeleted &&
                        client.User.IsActive &&
                        !client.User.IsBlocked,
                    cancellationToken);

        var totalTherapists =
            await _context.Therapists
                .AsNoTracking()
                .CountAsync(
                    therapist =>
                        !therapist.IsDeleted,
                    cancellationToken);

        var verifiedTherapists =
            await _context.Therapists
                .AsNoTracking()
                .CountAsync(
                    therapist =>
                        !therapist.IsDeleted &&
                        therapist.VerificationStatus ==
                            TherapistVerificationStatus.Approved,
                    cancellationToken);

        var pendingTherapists =
            await _context.Therapists
                .AsNoTracking()
                .CountAsync(
                    therapist =>
                        !therapist.IsDeleted &&
                        therapist.VerificationStatus ==
                            TherapistVerificationStatus.Pending,
                    cancellationToken);

        var appointmentsForPeriod =
            await _context.Appointments
                .AsNoTracking()
                .Where(appointment =>
                    !appointment.IsDeleted &&
                    appointment.StartUtc >=
                        query.FromUtc &&
                    appointment.StartUtc <
                        periodEndExclusive)
                .Select(appointment => new
                {
                    appointment.Status
                })
                .ToListAsync(
                    cancellationToken);

        var appointmentsByStatus =
            appointmentsForPeriod
                .GroupBy(appointment =>
                    appointment.Status)
                .OrderBy(group =>
                    group.Key)
                .Select(group =>
                    new AdminDashboardCountItemDto
                    {
                        Label =
                            group.Key.ToString(),

                        Count =
                            group.Count()
                    })
                .ToList();

        var appointmentTherapyApproachRecords =
    await _context.Appointments
        .AsNoTracking()
        .Where(appointment =>
            !appointment.IsDeleted &&
            !appointment.Therapist.IsDeleted &&
            appointment.StartUtc >=
                query.FromUtc &&
            appointment.StartUtc <
                periodEndExclusive)
        .SelectMany(appointment =>
            appointment.Therapist
                .TherapyApproaches
                .Where(therapistApproach =>
                    !therapistApproach.IsDeleted &&
                    !therapistApproach
                        .TherapyApproach
                        .IsDeleted &&
                    therapistApproach
                        .TherapyApproach
                        .IsActive)
                .Select(therapistApproach =>
                    new
                    {
                        AppointmentId =
                            appointment.Id,

                        TherapyApproachName =
                            therapistApproach
                                .TherapyApproach
                                .Name
                    }))
        .ToListAsync(
            cancellationToken);

        var appointmentsByTherapyApproach =
            appointmentTherapyApproachRecords
                .Where(record =>
                    !string.IsNullOrWhiteSpace(
                        record.TherapyApproachName))
                .GroupBy(
                    record =>
                        record.TherapyApproachName.Trim(),
                    StringComparer.OrdinalIgnoreCase)
                .Select(group =>
                    new AdminDashboardCountItemDto
                    {
                        Label =
                            group.Key,

                        Count =
                            group
                                .Select(record =>
                                    record.AppointmentId)
                                .Distinct()
                                .Count()
                    })
                .OrderByDescending(item =>
                    item.Count)
                .ThenBy(item =>
                    item.Label)
                .ToList();

        var todayAppointments =
            await _context.Appointments
                .AsNoTracking()
                .CountAsync(
                    appointment =>
                        !appointment.IsDeleted &&
                        appointment.StartUtc >=
                            todayStartUtc &&
                        appointment.StartUtc <
                            tomorrowStartUtc,
                    cancellationToken);

        var appointmentPayments =
            await _context.Payments
                .AsNoTracking()
                .Where(payment =>
                    !payment.IsDeleted &&
                    payment.Status ==
                        PaymentStatus.Paid &&
                    payment.PaidAtUtc.HasValue)
                .Select(payment => new
                {
                    Amount =
                        payment.Amount,

                    PaidAtUtc =
                        payment.PaidAtUtc!.Value
                })
                .ToListAsync(
                    cancellationToken);

        var membershipPayments =
            await _context.MembershipPayments
                .AsNoTracking()
                .Where(payment =>
                    !payment.IsDeleted &&
                    payment.Status ==
                        PaymentStatus.Paid &&
                    payment.PaidAtUtc.HasValue)
                .Select(payment => new
                {
                    Amount =
                        payment.Amount,

                    PaidAtUtc =
                        payment.PaidAtUtc!.Value
                })
                .ToListAsync(
                    cancellationToken);

        var allPaidTransactions =
            appointmentPayments
                .Select(payment =>
                    new DashboardPaymentRecord
                    {
                        Amount =
                            payment.Amount,

                        PaidAtUtc =
                            payment.PaidAtUtc
                    })
                .Concat(
                    membershipPayments.Select(payment =>
                        new DashboardPaymentRecord
                        {
                            Amount =
                                payment.Amount,

                            PaidAtUtc =
                                payment.PaidAtUtc
                        }))
                .ToList();

        var totalRevenue =
            allPaidTransactions.Sum(
                payment =>
                    payment.Amount);

        var currentMonthRevenue =
            allPaidTransactions
                .Where(payment =>
                    payment.PaidAtUtc >=
                        currentMonthStartUtc &&
                    payment.PaidAtUtc <
                        nextMonthStartUtc)
                .Sum(payment =>
                    payment.Amount);

        var periodRevenue =
            allPaidTransactions
                .Where(payment =>
                    payment.PaidAtUtc >=
                        query.FromUtc &&
                    payment.PaidAtUtc <
                        periodEndExclusive)
                .Sum(payment =>
                    payment.Amount);

        var revenueByMonth =
            allPaidTransactions
                .Where(payment =>
                    payment.PaidAtUtc >=
                        query.FromUtc &&
                    payment.PaidAtUtc <
                        periodEndExclusive)
                .GroupBy(payment => new
                {
                    payment.PaidAtUtc.Year,
                    payment.PaidAtUtc.Month
                })
                .OrderBy(group =>
                    group.Key.Year)
                .ThenBy(group =>
                    group.Key.Month)
                .Select(group =>
                    new AdminDashboardMonthlyRevenueItemDto
                    {
                        Year =
                            group.Key.Year,

                        Month =
                            group.Key.Month,

                        Label =
                            BuildMonthLabel(
                                group.Key.Year,
                                group.Key.Month),

                        Revenue =
                            group.Sum(payment =>
                                payment.Amount)
                    })
                .ToList();

        var newUsersByMonth =
            await _context.Users
                .AsNoTracking()
                .Where(user =>
                    user.CreatedAtUtc >=
                        query.FromUtc &&
                    user.CreatedAtUtc <
                        periodEndExclusive)
                .GroupBy(user => new
                {
                    user.CreatedAtUtc.Year,
                    user.CreatedAtUtc.Month
                })
                .OrderBy(group =>
                    group.Key.Year)
                .ThenBy(group =>
                    group.Key.Month)
                .Select(group =>
                    new AdminDashboardMonthlyCountItemDto
                    {
                        Year =
                            group.Key.Year,

                        Month =
                            group.Key.Month,

                        Count =
                            group.Count()
                    })
                .ToListAsync(
                    cancellationToken);

        var verifiedTherapistsByMonth =
    await _context
        .TherapistVerificationAudits
        .AsNoTracking()
        .Where(audit =>
            audit.NewStatus ==
                TherapistVerificationStatus.Approved &&
            audit.ChangedAtUtc >=
                query.FromUtc &&
            audit.ChangedAtUtc <
                periodEndExclusive)
        .GroupBy(audit => new
        {
            audit.ChangedAtUtc.Year,
            audit.ChangedAtUtc.Month
        })
        .OrderBy(group =>
            group.Key.Year)
        .ThenBy(group =>
            group.Key.Month)
        .Select(group =>
            new AdminDashboardMonthlyCountItemDto
            {
                Year =
                    group.Key.Year,

                Month =
                    group.Key.Month,

                Count =
                    group
                        .Select(audit =>
                            audit.TherapistId)
                        .Distinct()
                        .Count()
            })
        .ToListAsync(
            cancellationToken);

        foreach (var item in verifiedTherapistsByMonth)
        {
            item.Label =
                BuildMonthLabel(
                    item.Year,
                    item.Month);
        }

        foreach (var item in newUsersByMonth)
        {
            item.Label =
                BuildMonthLabel(
                    item.Year,
                    item.Month);
        }

        var activeMemberships =
            await _context.ClientMemberships
                .AsNoTracking()
                .CountAsync(
                    membership =>
                        !membership.IsDeleted &&
                        membership.IsActive &&
                        membership.RemainingSessions > 0 &&
                        (
                            membership.ExpiresAtUtc == null ||
                            membership.ExpiresAtUtc >
                                nowUtc
                        ) &&
                        membership.Payment != null &&
                        membership.Payment.Status ==
                            PaymentStatus.Paid,
                    cancellationToken);

        var pendingReviews =
            await _context.Reviews
                .AsNoTracking()
                .CountAsync(
                    review =>
                        !review.IsDeleted &&
                        !review.IsApproved,
                    cancellationToken);

        var publishedArticles =
            await _context.Articles
                .AsNoTracking()
                .CountAsync(
                    article =>
                        !article.IsDeleted &&
                        article.IsPublished,
                    cancellationToken);

        var activeWorkshops =
            await _context.Workshops
                .AsNoTracking()
                .CountAsync(
                    workshop =>
                        !workshop.IsDeleted &&
                        workshop.Status ==
                            WorkshopStatus.Scheduled &&
                        workshop.EndUtc >
                            nowUtc,
                    cancellationToken);

        return new AdminDashboardReportDto
        {
            FromUtc =
                query.FromUtc,

            ToUtc =
                query.ToUtc,

            GeneratedAtUtc =
                nowUtc,

            TotalUsers =
                totalUsers,

            ActiveClients =
                activeClients,

            TotalTherapists =
                totalTherapists,

            VerifiedTherapists =
                verifiedTherapists,

            PendingTherapists =
                pendingTherapists,

            TotalAppointments =
                appointmentsForPeriod.Count,

            TodayAppointments =
                todayAppointments,

            CompletedAppointments =
                appointmentsForPeriod.Count(
                    appointment =>
                        appointment.Status ==
                            AppointmentStatus.Completed),

            CancelledAppointments =
                appointmentsForPeriod.Count(
                    appointment =>
                        appointment.Status ==
                            AppointmentStatus.Cancelled ||
                        appointment.Status ==
                            AppointmentStatus.Rejected),

            TotalRevenue =
                totalRevenue,

            CurrentMonthRevenue =
                currentMonthRevenue,

            PeriodRevenue =
                periodRevenue,

            ActiveMemberships =
                activeMemberships,

            PendingReviews =
                pendingReviews,

            PublishedArticles =
                publishedArticles,

            ActiveWorkshops =
                activeWorkshops,

            AppointmentsByStatus =
                appointmentsByStatus,

            RevenueByMonth =
                revenueByMonth,

            NewUsersByMonth = newUsersByMonth,

            AppointmentsByTherapyApproach =
    appointmentsByTherapyApproach,

            VerifiedTherapistsByMonth =
    verifiedTherapistsByMonth
        };
    }

    public async Task<AppointmentRevenueReportDto>
    GetAppointmentRevenueReportAsync(
        int authenticatedAdminUserId,
        AppointmentRevenueReportQueryDto query,
        CancellationToken cancellationToken = default)
    {
        ValidateAppointmentRevenuePeriod(
            query);

        var admin =
            await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x =>
                        x.Id ==
                            authenticatedAdminUserId &&
                        !x.IsBlocked,
                    cancellationToken);

        if (admin == null)
        {
            throw new InvalidOperationException(
                "Administrator was not found.");
        }

        string generatedByAdmin =
            BuildFullName(
                admin.FirstName,
                admin.LastName,
                admin.Id);

        string? therapistName = null;

        if (query.TherapistId.HasValue)
        {
            var therapist =
                await _context.Therapists
                    .AsNoTracking()
                    .Where(x =>
                        x.Id ==
                            query.TherapistId.Value &&
                        !x.IsDeleted)
                    .Select(x => new
                    {
                        x.Id,
                        x.User.FirstName,
                        x.User.LastName
                    })
                    .FirstOrDefaultAsync(
                        cancellationToken);

            if (therapist == null)
            {
                throw new ArgumentException(
                    "Selected therapist was not found.");
            }

            therapistName =
                BuildFullName(
                    therapist.FirstName,
                    therapist.LastName,
                    therapist.Id);
        }

        var appointmentsQuery =
            _context.Appointments
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.StartUtc >= query.FromUtc &&
                    x.StartUtc <= query.ToUtc);

        if (query.TherapistId.HasValue)
        {
            appointmentsQuery =
                appointmentsQuery.Where(x =>
                    x.TherapistId ==
                    query.TherapistId.Value);
        }

        if (query.AppointmentStatus.HasValue)
        {
            appointmentsQuery =
                appointmentsQuery.Where(x =>
                    x.Status ==
                    query.AppointmentStatus.Value);
        }

        if (query.AppointmentType.HasValue)
        {
            appointmentsQuery =
                appointmentsQuery.Where(x =>
                    x.Type ==
                    query.AppointmentType.Value);
        }

        if (query.PaymentStatus.HasValue)
        {
            appointmentsQuery =
                appointmentsQuery.Where(x =>
                    x.Payment != null &&
                    !x.Payment.IsDeleted &&
                    x.Payment.Status ==
                        query.PaymentStatus.Value);
        }

        var appointments =
            await appointmentsQuery
                .OrderBy(x => x.StartUtc)
                .ThenBy(x => x.Id)
                .Select(x =>
                    new AppointmentRevenueReportRecord
                    {
                        AppointmentId =
                            x.Id,

                        ClientId =
                            x.ClientId,

                        ClientName =
                            x.Client.User.FirstName
                            + " "
                            + x.Client.User.LastName,

                        TherapistId =
                            x.TherapistId,

                        TherapistName =
                            x.Therapist.User.FirstName
                            + " "
                            + x.Therapist.User.LastName,

                        StartUtc =
                            x.StartUtc,

                        EndUtc =
                            x.EndUtc,

                        Status =
                            x.Status,

                        Type =
                            x.Type,

                        AppointmentPrice =
                            x.Price,

                        IsPaid =
                            x.IsPaid,

                        PaymentId =
                            x.Payment != null &&
                            !x.Payment.IsDeleted
                                ? x.Payment.Id
                                : null,

                        PaymentStatus =
                            x.Payment != null &&
                            !x.Payment.IsDeleted
                                ? x.Payment.Status
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
                .ToListAsync(
                    cancellationToken);

        var appointmentsByStatus =
            appointments
                .GroupBy(x => x.Status)
                .OrderBy(x => x.Key)
                .Select(group =>
                    new AppointmentStatusReportItemDto
                    {
                        Status =
                            group.Key.ToString(),

                        Count =
                            group.Count()
                    })
                .ToList();

        var paymentRecords =
            appointments
                .Where(x =>
                    x.PaymentId.HasValue)
                .ToList();

        var paidPayments =
            paymentRecords
                .Where(x =>
                    x.PaidAtUtc.HasValue)
                .ToList();

        var refundRequestedPayments =
            paidPayments
                .Where(x =>
                    x.RefundRequestedAtUtc
                        .HasValue)
                .ToList();

        var refundedPayments =
            paidPayments
                .Where(x =>
                    x.RefundedAtUtc.HasValue)
                .ToList();

        var failedRefundPayments =
            paidPayments
                .Where(x =>
                    !string.IsNullOrWhiteSpace(
                        x.RefundFailureReason))
                .ToList();

        var grossRevenue =
            paidPayments.Sum(x =>
                x.PaymentAmount);

        /*
         * Trenutni Payment model nema zaseban
         * PartialRefundAmount, pa refund predstavlja
         * puni refund originalnog iznosa.
         */
        var refundedAmount =
            refundedPayments.Sum(x =>
                x.PaymentAmount);

        var netRevenue =
            grossRevenue -
            refundedAmount;

        var reportItems =
            appointments
                .Select(x =>
                    new AppointmentRevenueReportItemDto
                    {
                        AppointmentId =
                            x.AppointmentId,

                        ClientName =
                            x.ClientName.Trim(),

                        TherapistName =
                            x.TherapistName.Trim(),

                        StartUtc =
                            x.StartUtc,

                        EndUtc =
                            x.EndUtc,

                        AppointmentStatus =
                            x.Status.ToString(),

                        AppointmentType =
                            x.Type.ToString(),

                        Price =
                            x.AppointmentPrice,

                        PaymentStatus =
                            x.PaymentStatus.HasValue
                                ? x.PaymentStatus
                                    .Value
                                    .ToString()
                                : "Unpaid",

                        PaidAmount =
                            x.PaidAtUtc.HasValue
                                ? x.PaymentAmount
                                : 0,

                        RefundedAmount =
                            x.RefundedAtUtc.HasValue
                                ? x.PaymentAmount
                                : 0
                    })
                .ToList();

        return new AppointmentRevenueReportDto
        {
            FromUtc =
                query.FromUtc,

            ToUtc =
                query.ToUtc,

            GeneratedAtUtc =
                DateTime.UtcNow,

            GeneratedByAdmin =
                generatedByAdmin,

            TherapistId =
                query.TherapistId,

            TherapistName =
                therapistName,

            AppointmentStatusFilter =
                query.AppointmentStatus?
                    .ToString(),

            AppointmentTypeFilter =
                query.AppointmentType?
                    .ToString(),

            PaymentStatusFilter =
                query.PaymentStatus?
                    .ToString(),

            TotalAppointments =
                appointments.Count,

            CompletedAppointments =
                appointments.Count(x =>
                    x.Status ==
                        AppointmentStatus.Completed),

            CancelledAppointments =
                appointments.Count(x =>
                    x.Status ==
                        AppointmentStatus.Cancelled ||
                    x.Status ==
                        AppointmentStatus.Rejected),

            UniqueClientsCount =
                appointments
                    .Select(x => x.ClientId)
                    .Distinct()
                    .Count(),

            UniqueTherapistsCount =
                appointments
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
                },

            Appointments =
                reportItems
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

    private static void
    ValidateAppointmentRevenuePeriod(
        AppointmentRevenueReportQueryDto query)
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

        if (query.FromUtc >
            query.ToUtc)
        {
            throw new ArgumentException(
                "Report start date cannot be later than the end date.");
        }

        var maximumPeriod =
            TimeSpan.FromDays(
                366 * 5);

        if (query.ToUtc -
            query.FromUtc >
            maximumPeriod)
        {
            throw new ArgumentException(
                "Report period cannot be longer than five years.");
        }

        if (query.TherapistId.HasValue &&
            query.TherapistId.Value <= 0)
        {
            throw new ArgumentException(
                "Therapist ID must be greater than zero.");
        }
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

    private static void ValidateDashboardPeriod(
    AdminDashboardReportQueryDto query)
    {
        if (query.FromUtc == default)
        {
            throw new ArgumentException(
                "Dashboard start date is required.");
        }

        if (query.ToUtc == default)
        {
            throw new ArgumentException(
                "Dashboard end date is required.");
        }

        if (query.FromUtc > query.ToUtc)
        {
            throw new ArgumentException(
                "Dashboard start date cannot be later than the end date.");
        }

        var maximumPeriod =
            TimeSpan.FromDays(366 * 5);

        if (query.ToUtc - query.FromUtc >
            maximumPeriod)
        {
            throw new ArgumentException(
                "Dashboard period cannot be longer than five years.");
        }
    }

    private static string BuildMonthLabel(
        int year,
        int month)
    {
        return $"{year}-{month:D2}";
    }

    private sealed class DashboardPaymentRecord
    {
        public decimal Amount { get; set; }

        public DateTime PaidAtUtc { get; set; }
    }

    private sealed class AppointmentRevenueReportRecord
    {
        public int AppointmentId { get; set; }

        public int ClientId { get; set; }

        public string ClientName { get; set; } =
            string.Empty;

        public int TherapistId { get; set; }

        public string TherapistName { get; set; } =
            string.Empty;

        public DateTime StartUtc { get; set; }

        public DateTime EndUtc { get; set; }

        public AppointmentStatus Status { get; set; }

        public AppointmentType Type { get; set; }

        public decimal AppointmentPrice { get; set; }

        public bool IsPaid { get; set; }

        public int? PaymentId { get; set; }

        public PaymentStatus? PaymentStatus { get; set; }

        public decimal PaymentAmount { get; set; }

        public DateTime? PaidAtUtc { get; set; }

        public DateTime? RefundRequestedAtUtc { get; set; }

        public DateTime? RefundedAtUtc { get; set; }

        public string? RefundFailureReason { get; set; }
    }
}