using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;

namespace MindBloom.Infrastructure.Services;

public class MembershipService : IMembershipService
{
    private const string PaymentCurrency = "usd";

    private readonly ApplicationDbContext _context;

    private readonly StripeVerificationService
        _stripeVerificationService;

    public MembershipService(
        ApplicationDbContext context,
        StripeVerificationService stripeVerificationService)
    {
        _context = context;

        _stripeVerificationService =
            stripeVerificationService;
    }

    public async Task<List<MembershipPlanDto>>
        GetPlansForTherapistAsync(
            int therapistId)
    {
        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        var sessionPrice =
            therapist.HourlyRate;

        if (sessionPrice <= 0)
        {
            throw new Exception(
                "Therapist session price is invalid.");
        }

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

    public async Task<MembershipPaymentIntentResponseDto>
        CreatePaymentIntentAsync(
            int clientUserId,
            CreateMembershipPaymentIntentDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var therapist =
            await _context.Therapists
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == request.TherapistId &&
                    !x.IsDeleted);

        if (therapist == null)
        {
            throw new Exception(
                "Therapist not found.");
        }

        ValidatePlanType(
            request.PlanType);

        var activeMembershipExists =
            await _context.ClientMemberships
                .AnyAsync(x =>
                    x.ClientId == client.Id &&
                    x.TherapistId ==
                        request.TherapistId &&
                    x.IsActive &&
                    x.RemainingSessions > 0 &&
                    !x.IsDeleted &&
                    (x.ExpiresAtUtc == null ||
                     x.ExpiresAtUtc >
                        DateTime.UtcNow));

        if (activeMembershipExists)
        {
            throw new Exception(
                "You already have an active membership for this therapist.");
        }

        var pendingMembership =
            await _context.ClientMemberships
                .Include(x => x.Payment)
                .FirstOrDefaultAsync(x =>
                    x.ClientId == client.Id &&
                    x.TherapistId ==
                        request.TherapistId &&
                    x.PlanType ==
                        request.PlanType &&
                    !x.IsActive &&
                    !x.IsDeleted &&
                    x.Payment != null &&
                    x.Payment.Status ==
                        PaymentStatus.Pending);

        if (pendingMembership?.Payment != null)
        {
            try
            {
                var existingPaymentIntent =
                    await _stripeVerificationService
                        .GetPaymentIntentAsync(
                            pendingMembership
                                .Payment
                                .StripePaymentIntentId);

                if (!string.Equals(
                        existingPaymentIntent.Status,
                        "canceled",
                        StringComparison.OrdinalIgnoreCase))
                {
                    return new MembershipPaymentIntentResponseDto
                    {
                        MembershipId =
                            pendingMembership.Id,

                        ClientSecret =
                            existingPaymentIntent
                                .ClientSecret,

                        PaymentIntentId =
                            existingPaymentIntent.Id,

                        Amount =
                            pendingMembership.Price,

                        Currency =
                            pendingMembership
                                .Payment
                                .Currency
                    };
                }

                pendingMembership.Payment.Status =
                    PaymentStatus.Failed;

                pendingMembership.IsDeleted =
                    true;

                await _context.SaveChangesAsync();
            }
            catch (StripeException)
            {
                pendingMembership.Payment.Status =
                    PaymentStatus.Failed;

                pendingMembership.IsDeleted =
                    true;

                await _context.SaveChangesAsync();
            }
        }

        var plan =
            CreatePlan(
                request.PlanType,
                GetPlanName(
                    request.PlanType),
                GetTotalSessions(
                    request.PlanType),
                GetFreeSessions(
                    request.PlanType),
                therapist.HourlyRate);

        if (plan.Price <= 0)
        {
            throw new Exception(
                "Membership price is invalid.");
        }

        var membership =
            new ClientMembership
            {
                ClientId =
                    client.Id,

                TherapistId =
                    therapist.Id,

                PlanType =
                    request.PlanType,

                TotalSessions =
                    plan.TotalSessions,

                RemainingSessions =
                    0,

                Price =
                    plan.Price,

                IsActive =
                    false,

                PurchasedAtUtc =
                    null,

                ExpiresAtUtc =
                    null
            };

        _context.ClientMemberships.Add(
            membership);

        await _context.SaveChangesAsync();

        var secretKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SECRET_KEY");

        if (string.IsNullOrWhiteSpace(
                secretKey))
        {
            membership.IsDeleted = true;

            await _context.SaveChangesAsync();

            throw new Exception(
                "Stripe configuration is missing.");
        }

        StripeConfiguration.ApiKey =
            secretKey;

        var paymentIntentOptions =
            new PaymentIntentCreateOptions
            {
                Amount =
                    ConvertToMinorUnits(
                        plan.Price),

                Currency =
                    PaymentCurrency,

                AutomaticPaymentMethods =
                    new PaymentIntentAutomaticPaymentMethodsOptions
                    {
                        Enabled = true
                    },

                Description =
                    $"MindBloom membership "
                    + $"{membership.Id}",

                Metadata =
                    new Dictionary<string, string>
                    {
                        ["purchaseType"] =
                            "membership",

                        ["membershipId"] =
                            membership.Id
                                .ToString(),

                        ["clientUserId"] =
                            clientUserId
                                .ToString(),

                        ["clientId"] =
                            client.Id
                                .ToString(),

                        ["therapistId"] =
                            therapist.Id
                                .ToString(),

                        ["planType"] =
                            request.PlanType
                                .ToString()
                    }
            };

        var requestOptions =
            new RequestOptions
            {
                IdempotencyKey =
                    $"mindbloom-membership-{membership.Id}"
            };

        PaymentIntent stripePaymentIntent;

        try
        {
            var paymentIntentService =
                new PaymentIntentService();

            stripePaymentIntent =
                await paymentIntentService
                    .CreateAsync(
                        paymentIntentOptions,
                        requestOptions);
        }
        catch (StripeException exception)
        {
            membership.IsDeleted =
                true;

            await _context.SaveChangesAsync();

            throw new Exception(
                "Stripe membership payment could not be created.",
                exception);
        }

        var membershipPayment =
            new MembershipPayment
            {
                ClientMembershipId =
                    membership.Id,

                Amount =
                    plan.Price,

                Currency =
                    PaymentCurrency,

                Status =
                    PaymentStatus.Pending,

                StripePaymentIntentId =
                    stripePaymentIntent.Id
            };

        _context.MembershipPayments.Add(
            membershipPayment);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException exception)
        {
            throw new Exception(
                "A membership payment already exists for this purchase.",
                exception);
        }

        return new MembershipPaymentIntentResponseDto
        {
            MembershipId =
                membership.Id,

            ClientSecret =
                stripePaymentIntent.ClientSecret,

            PaymentIntentId =
                stripePaymentIntent.Id,

            Amount =
                plan.Price,

            Currency =
                PaymentCurrency
        };
    }

    public async Task<MembershipResponseDto>
        ConfirmPaymentAsync(
            int clientUserId,
            ConfirmMembershipPaymentDto request)
    {
        if (string.IsNullOrWhiteSpace(
                request.PaymentIntentId))
        {
            throw new Exception(
                "Payment intent ID is required.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var membershipPayment =
            await _context.MembershipPayments
                .Include(x =>
                    x.ClientMembership)
                .ThenInclude(x =>
                    x.Therapist)
                .ThenInclude(x =>
                    x.User)
                .FirstOrDefaultAsync(x =>
                    x.StripePaymentIntentId ==
                        request.PaymentIntentId);

        if (membershipPayment == null)
        {
            throw new Exception(
                "Membership payment not found.");
        }

        var membership =
            membershipPayment.ClientMembership;

        if (membership.ClientId !=
            client.Id)
        {
            throw new Exception(
                "This membership payment does not belong to you.");
        }

        /*
         * Idempotent confirmation:
         * ako je već plaćeno i membership aktiviran,
         * samo vraćamo trenutno stanje.
         */
        if (membershipPayment.Status ==
                PaymentStatus.Paid &&
            membership.IsActive)
        {
            return MapMembership(
                membership,
                membership.Therapist,
                membershipPayment);
        }

        if (membershipPayment.Status ==
            PaymentStatus.Refunded)
        {
            throw new Exception(
                "This membership payment has been refunded.");
        }

        PaymentIntent stripePaymentIntent;

        try
        {
            stripePaymentIntent =
                await _stripeVerificationService
                    .GetPaymentIntentAsync(
                        request.PaymentIntentId);
        }
        catch (StripeException exception)
        {
            throw new Exception(
                "Membership payment could not be verified with Stripe.",
                exception);
        }

        if (!string.Equals(
                stripePaymentIntent.Status,
                "succeeded",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception(
                "Stripe membership payment has not succeeded. "
                + $"Current status: {stripePaymentIntent.Status}.");
        }

        var expectedAmount =
            ConvertToMinorUnits(
                membership.Price);

        if (stripePaymentIntent.Amount !=
            expectedAmount)
        {
            throw new Exception(
                "Stripe membership amount does not match the server-calculated price.");
        }

        if (!string.Equals(
                stripePaymentIntent.Currency,
                PaymentCurrency,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception(
                "Stripe membership currency is invalid.");
        }

        ValidateMetadata(
            stripePaymentIntent,
            membership,
            clientUserId,
            client.Id);

        var duplicateActiveMembership =
            await _context.ClientMemberships
                .AnyAsync(x =>
                    x.Id != membership.Id &&
                    x.ClientId ==
                        client.Id &&
                    x.TherapistId ==
                        membership.TherapistId &&
                    x.IsActive &&
                    x.RemainingSessions > 0 &&
                    !x.IsDeleted &&
                    (x.ExpiresAtUtc == null ||
                     x.ExpiresAtUtc >
                        DateTime.UtcNow));

        if (duplicateActiveMembership)
        {
            throw new Exception(
                "You already have another active membership for this therapist.");
        }

        membershipPayment.Status =
            PaymentStatus.Paid;

        membershipPayment.PaidAtUtc =
            DateTime.UtcNow;

        membership.RemainingSessions =
            membership.TotalSessions;

        membership.IsActive =
            true;

        membership.PurchasedAtUtc =
            DateTime.UtcNow;

        membership.ExpiresAtUtc =
            DateTime.UtcNow.AddMonths(6);

        await _context.SaveChangesAsync();

        return MapMembership(
            membership,
            membership.Therapist,
            membershipPayment);
    }

    public async Task<List<MembershipResponseDto>>
        GetMyMembershipsAsync(
            int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        return await _context.ClientMemberships
            .Include(x => x.Therapist)
                .ThenInclude(x => x.User)
            .Include(x => x.Payment)
            .Where(x =>
                x.ClientId == client.Id &&
                !x.IsDeleted)
            .OrderByDescending(x =>
                x.PurchasedAtUtc ??
                x.CreatedAtUtc)
            .Select(x =>
                new MembershipResponseDto
                {
                    Id =
                        x.Id,

                    TherapistId =
                        x.TherapistId,

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

                    Price =
                        x.Price,

                    IsActive =
                        x.IsActive,

                    IsPaid =
                        x.Payment != null &&
                        x.Payment.Status ==
                            PaymentStatus.Paid,

                    PaymentStatus =
                        x.Payment == null
                            ? "NotCreated"
                            : x.Payment.Status
                                .ToString(),

                    PurchasedAtUtc =
                        x.PurchasedAtUtc,

                    ExpiresAtUtc =
                        x.ExpiresAtUtc
                })
            .ToListAsync();
    }

    public async Task<MembershipReceiptDto>
        GetReceiptAsync(
            int clientUserId,
            int membershipId)
    {
        var client =
            await _context.Clients
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var membership =
            await _context.ClientMemberships
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Payment)
                .FirstOrDefaultAsync(x =>
                    x.Id == membershipId &&
                    x.ClientId == client.Id &&
                    !x.IsDeleted);

        if (membership == null)
        {
            throw new Exception(
                "Membership not found.");
        }

        if (membership.Payment == null ||
            membership.Payment.Status !=
                PaymentStatus.Paid ||
            membership.Payment.PaidAtUtc ==
                null)
        {
            throw new Exception(
                "Receipt is available only for a paid membership.");
        }

        return new MembershipReceiptDto
        {
            MembershipId =
                membership.Id,

            PaymentId =
                membership.Payment.Id,

            InvoiceNumber =
                $"MEM-{membership.Payment.Id:D6}",

            ClientName =
                client.User.FirstName
                + " "
                + client.User.LastName,

            TherapistName =
                membership.Therapist.User.FirstName
                + " "
                + membership.Therapist.User.LastName,

            PlanType =
                membership.PlanType.ToString(),

            TotalSessions =
                membership.TotalSessions,

            Amount =
                membership.Payment.Amount,

            Currency =
                membership.Payment.Currency
                    .ToUpperInvariant(),

            PaymentStatus =
                membership.Payment.Status
                    .ToString(),

            PaidAtUtc =
                membership.Payment.PaidAtUtc
                    .Value,

            ExpiresAtUtc =
                membership.ExpiresAtUtc
        };
    }

    public async Task UseMembershipAsync(
        int clientUserId,
        UseMembershipDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        request.AppointmentId &&
                    x.ClientId ==
                        client.Id);

        if (appointment == null)
        {
            throw new Exception(
                "Appointment not found.");
        }

        if (appointment.Status !=
            AppointmentStatus.Accepted)
        {
            throw new Exception(
                "Membership can only be used for accepted appointments.");
        }

        if (appointment.IsPaid)
        {
            throw new Exception(
                "This appointment has already been paid.");
        }

        var alreadyUsed =
            await _context.MembershipUsages
                .AnyAsync(x =>
                    x.AppointmentId ==
                        appointment.Id);

        if (alreadyUsed)
        {
            throw new Exception(
                "Membership has already been used for this appointment.");
        }

        var membership =
            await _context.ClientMemberships
                .Include(x => x.Payment)
                .FirstOrDefaultAsync(x =>
                    x.ClientId ==
                        client.Id &&
                    x.TherapistId ==
                        appointment.TherapistId &&
                    x.IsActive &&
                    x.Payment != null &&
                    x.Payment.Status ==
                        PaymentStatus.Paid &&
                    x.RemainingSessions > 0 &&
                    !x.IsDeleted &&
                    (x.ExpiresAtUtc == null ||
                     x.ExpiresAtUtc >
                        DateTime.UtcNow));

        if (membership == null)
        {
            throw new Exception(
                "No active paid membership is available for this therapist.");
        }

        membership.RemainingSessions--;

        if (membership.RemainingSessions == 0)
        {
            membership.IsActive =
                false;
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

    private static void ValidateMetadata(
        PaymentIntent stripePaymentIntent,
        ClientMembership membership,
        int clientUserId,
        int clientId)
    {
        var metadata =
            stripePaymentIntent.Metadata;

        if (metadata == null)
        {
            throw new Exception(
                "Stripe membership metadata is missing.");
        }

        if (!metadata.TryGetValue(
                "purchaseType",
                out var purchaseType) ||
            !string.Equals(
                purchaseType,
                "membership",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception(
                "Stripe payment is not a membership purchase.");
        }

        if (!metadata.TryGetValue(
                "membershipId",
                out var membershipIdValue) ||
            !int.TryParse(
                membershipIdValue,
                out var membershipId) ||
            membershipId != membership.Id)
        {
            throw new Exception(
                "Stripe payment is linked to a different membership.");
        }

        if (!metadata.TryGetValue(
                "clientUserId",
                out var clientUserIdValue) ||
            !int.TryParse(
                clientUserIdValue,
                out var metadataClientUserId) ||
            metadataClientUserId != clientUserId)
        {
            throw new Exception(
                "Stripe payment is linked to a different user.");
        }

        if (!metadata.TryGetValue(
                "clientId",
                out var clientIdValue) ||
            !int.TryParse(
                clientIdValue,
                out var metadataClientId) ||
            metadataClientId != clientId)
        {
            throw new Exception(
                "Stripe payment is linked to a different client.");
        }

        if (!metadata.TryGetValue(
                "therapistId",
                out var therapistIdValue) ||
            !int.TryParse(
                therapistIdValue,
                out var therapistId) ||
            therapistId != membership.TherapistId)
        {
            throw new Exception(
                "Stripe payment is linked to a different therapist.");
        }
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
            PlanType =
                planType,

            Name =
                name,

            TotalSessions =
                totalSessions,

            FreeSessions =
                freeSessions,

            Price =
                price,

            PricePerSession =
                totalSessions == 0
                    ? 0
                    : price /
                      totalSessions
        };
    }

    private static void ValidatePlanType(
        MembershipPlanType planType)
    {
        if (!Enum.IsDefined(
                typeof(MembershipPlanType),
                planType))
        {
            throw new Exception(
                "Invalid membership plan.");
        }
    }

    private static int GetTotalSessions(
        MembershipPlanType planType)
    {
        return planType switch
        {
            MembershipPlanType.TenSessions =>
                10,

            MembershipPlanType.TwentySessions =>
                20,

            MembershipPlanType.ThirtySessions =>
                30,

            _ => throw new Exception(
                "Invalid membership plan.")
        };
    }

    private static int GetFreeSessions(
        MembershipPlanType planType)
    {
        return planType switch
        {
            MembershipPlanType.TenSessions =>
                1,

            MembershipPlanType.TwentySessions =>
                2,

            MembershipPlanType.ThirtySessions =>
                3,

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

            _ =>
                "Membership package"
        };
    }

    private static MembershipResponseDto
        MapMembership(
            ClientMembership membership,
            Therapist therapist,
            MembershipPayment? payment)
    {
        return new MembershipResponseDto
        {
            Id =
                membership.Id,

            TherapistId =
                membership.TherapistId,

            TherapistName =
                therapist.User.FirstName
                + " "
                + therapist.User.LastName,

            PlanType =
                membership.PlanType
                    .ToString(),

            TotalSessions =
                membership.TotalSessions,

            RemainingSessions =
                membership.RemainingSessions,

            Price =
                membership.Price,

            IsActive =
                membership.IsActive,

            IsPaid =
                payment?.Status ==
                    PaymentStatus.Paid,

            PaymentStatus =
                payment?.Status
                    .ToString() ??
                "NotCreated",

            PurchasedAtUtc =
                membership.PurchasedAtUtc,

            ExpiresAtUtc =
                membership.ExpiresAtUtc
        };
    }

    private static long ConvertToMinorUnits(
        decimal amount)
    {
        return decimal.ToInt64(
            decimal.Round(
                amount * 100,
                0,
                MidpointRounding
                    .AwayFromZero));
    }
}