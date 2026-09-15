using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;
using System.Data;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Messaging.Contracts.Memberships;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.Infrastructure.Services;

public class MembershipService : IMembershipService
{
    private const string PaymentCurrency = "usd";
    private const int MembershipDurationMonths = 6;

    private readonly ApplicationDbContext _context;
    private readonly StripeClientProvider
    _stripeClientProvider;
    private readonly IOutboxWriter
    _outboxWriter;
    private readonly StripeVerificationService _stripeVerificationService;
    private readonly IIntegrationEventPublisher
    _integrationEventPublisher;


    public MembershipService(
        ApplicationDbContext context,
        StripeVerificationService
            stripeVerificationService,
        IIntegrationEventPublisher
            integrationEventPublisher,
        IOutboxWriter outboxWriter)
    {
        _context =
            context;

        _stripeVerificationService =
            stripeVerificationService;

        _integrationEventPublisher =
            integrationEventPublisher;

        _outboxWriter =
            outboxWriter;
    }

    public async Task<List<MembershipPlanDto>>
     GetPlansForTherapistAsync(
         int therapistId)
    {
        var therapist =
            await _context.Therapists
                .AsNoTracking()
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == therapistId
                    && !x.IsDeleted
                    && !x.User.IsBlocked
                    && x.User.IsActive);

        if (therapist == null)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var plans =
            await _context.MembershipPlans
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted
                    && x.IsActive)
                .OrderBy(x =>
                    x.IncludedSessions)
                .ThenBy(x =>
                    x.Price)
                .ToListAsync();

        return plans
            .Select(plan =>
            {
                var benefits =
                    DeserializeBenefits(
                        plan.BenefitsJson);

                return new MembershipPlanDto
                {
                    PlanType =
                        plan.PlanType,

                    Name =
                        plan.Name,

                    Description =
                        plan.Description,

                    TotalSessions =
                        plan.IncludedSessions,

                    FreeSessions =
                        CalculateFreeSessions(
                            plan.IncludedSessions,
                            plan.DiscountPercentage),

                    Price =
                        plan.Price,

                    PricePerSession =
                        plan.IncludedSessions <= 0
                            ? 0
                            : decimal.Round(
                                plan.Price
                                / plan.IncludedSessions,
                                2),

                    DurationMonths =
                        plan.DurationMonths,

                    IsActive =
                        plan.IsActive,

                    Benefits =
                        benefits
                };
            })
            .ToList();
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
            throw new NotFoundException(
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
            throw new NotFoundException(
                "Therapist not found.");
        }

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
            BusinessRuleGuard.Against(
    activeMembershipExists,
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
            await _context.MembershipPlans
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.PlanType ==
                        request.PlanType
                    && !x.IsDeleted);

        if (plan == null)
        {
            throw new NotFoundException(
                "Membership plan not found.");
        }

        BusinessRuleGuard.Against(
            !plan.IsActive,
            "Selected membership plan is not currently available.");

        if (plan.Price <= 0)
        {
            throw new BusinessException(
                "Membership price is invalid.");
        }

        if (plan.IncludedSessions <= 0)
        {
            throw new BusinessException(
                "Membership plan must include at least one session.");
        }

        if (plan.DurationMonths <= 0)
        {
            throw new BusinessException(
                "Membership duration is invalid.");
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
    plan.IncludedSessions,

                RemainingSessions =
                    0,

                Price =
                    plan.Price,

                IsActive =
                    false,

                PurchasedAtUtc =
                    null,

                ExpiresAtUtc =
                    null,

                DurationMonths =
    plan.DurationMonths,
            };

        _context.ClientMemberships.Add(
            membership);

        await _context.SaveChangesAsync();

       

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
                new PaymentIntentService(
                    _stripeClientProvider.Client);

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
            throw new BusinessException(
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

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
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
            throw new NotFoundException(
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
            BusinessRuleGuard.Against(
    duplicateActiveMembership,
    "You already have another active membership for this therapist.");
        }

        membershipPayment.Status =
      PaymentStatus.Paid;

        membershipPayment.PaidAtUtc ??=
            DateTime.UtcNow;

        membership.RemainingSessions =
            membership.TotalSessions;

        membership.IsActive =
            true;

        membership.PurchasedAtUtc ??=
            DateTime.UtcNow;

        if (membership.DurationMonths <= 0)
        {
            throw new BusinessException(
                "Membership duration is invalid.");
        }

        membership.ExpiresAtUtc ??=
            membership.PurchasedAtUtc
                .Value
                .AddMonths(
                    membership.DurationMonths);

        var purchasedAtUtc =
            membership.PurchasedAtUtc
            ?? DateTime.UtcNow;

        var paidAtUtc =
            membershipPayment.PaidAtUtc
            ?? purchasedAtUtc;

        var membershipPurchasedEvent =
            new MembershipPurchasedEvent
            {
                MembershipId =
                    membership.Id,

                ClientId =
                    membership.ClientId,

                ClientUserId =
                    clientUserId,

                TherapistId =
                    membership.TherapistId,

                TherapistUserId =
                    membership.Therapist.UserId,

                PlanType =
                    membership.PlanType
                        .ToString(),

                TotalSessions =
                    membership.TotalSessions,

                Price =
                    membership.Price,

                Currency =
                    membershipPayment.Currency,

                PurchasedAtUtc =
                    purchasedAtUtc,

                ExpiresAtUtc =
                    membership.ExpiresAtUtc
            };

        var paymentSucceededEvent =
            new PaymentSucceededEvent
            {
                PaymentId =
                    membershipPayment.Id,

                PaymentType =
                    "Membership",

                AppointmentId =
                    null,

                MembershipId =
                    membership.Id,

                ClientUserId =
                    clientUserId,

                Amount =
                    membershipPayment.Amount,

                Currency =
                    membershipPayment.Currency,

                PaidAtUtc =
                    paidAtUtc
            };

        await _outboxWriter
            .EnqueueAsync(
                membershipPurchasedEvent,
                IntegrationEventRoutingKeys
                    .MembershipPurchased);

        await _outboxWriter
            .EnqueueAsync(
                paymentSucceededEvent,
                IntegrationEventRoutingKeys
                    .PaymentSucceeded);

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
            throw new NotFoundException(
                "Client not found.");
        }

        var nowUtc =
            DateTime.UtcNow;

        var memberships =
            await _context.ClientMemberships
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Payment)
                .Where(x =>
                    x.ClientId == client.Id &&
                    !x.IsDeleted)
                .OrderByDescending(x =>
                    x.PurchasedAtUtc ??
                    x.CreatedAtUtc)
                .ToListAsync();

        var stateChanged =
            false;

        var expiredMemberships =
            new List<ClientMembership>();

        foreach (var membership in memberships)
        {
            var isExpired =
                membership.ExpiresAtUtc != null &&
                membership.ExpiresAtUtc <= nowUtc;

            var hasNoRemainingSessions =
                membership.RemainingSessions <= 0;

            if (membership.IsActive &&
                (
                    isExpired ||
                    hasNoRemainingSessions
                ))
            {
                membership.IsActive =
                    false;

                membership.UpdatedAtUtc =
                    nowUtc;

                stateChanged =
                    true;

                if (isExpired)
                {
                    expiredMemberships.Add(
                        membership);
                }
            }
        }

        if (stateChanged)
        {
            await _context.SaveChangesAsync();

            foreach (var membership
                     in expiredMemberships)
            {
                var notificationRequestedEvent =
                    new NotificationRequestedEvent
                    {
                        CorrelationId =
                            Guid.NewGuid(),

                        TimestampUtc =
                            nowUtc,

                        UserId =
                            clientUserId,

                        Title =
                            "Membership expired",

                        Message =
                            $"Your {GetPlanName(membership.PlanType)} "
                            + $"with {membership.Therapist.User.FirstName} "
                            + $"{membership.Therapist.User.LastName} "
                            + "has expired.",

                        AppointmentId =
                            null,

                        ActionType =
                            NotificationActionType
                                .Membership
                                .ToString(),

                        ResourceId =
                            membership.Id,

                        NotificationId =
                            null
                    };

                await _integrationEventPublisher
                    .PublishAsync(
                        notificationRequestedEvent,
                        IntegrationEventRoutingKeys
                            .NotificationRequested);
            }
        }

        return memberships
            .Select(x =>
            {
                var isExpired =
                    x.ExpiresAtUtc != null &&
                    x.ExpiresAtUtc <= nowUtc;

                return new MembershipResponseDto
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

                    PlanName =
                        GetPlanName(
                            x.PlanType),

                    TotalSessions =
                        x.TotalSessions,

                    RemainingSessions =
                        x.RemainingSessions,

                    UsedSessions =
                        Math.Max(
                            0,
                            x.TotalSessions -
                            x.RemainingSessions),

                    Price =
                        x.Price,

                    IsActive =
                        x.IsActive &&
                        !isExpired &&
                        x.RemainingSessions > 0,

                    IsPaid =
                        x.Payment != null &&
                        x.Payment.Status ==
                            PaymentStatus.Paid,

                    IsExpired =
                        isExpired,

                    PaymentStatus =
                        x.Payment == null
                            ? "NotCreated"
                            : x.Payment.Status
                                .ToString(),

                    PurchasedAtUtc =
                        x.PurchasedAtUtc,

                    ExpiresAtUtc =
                        x.ExpiresAtUtc
                };
            })
            .ToList();
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
            throw new NotFoundException(
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
            throw new NotFoundException(
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
        int therapistUserId =
    0;

        string therapistName =
            string.Empty;

        int remainingSessions =
            0;

        var strategy =
            _context.Database
                .CreateExecutionStrategy();

        await strategy.ExecuteAsync(
            async () =>
            {
                await using var transaction =
                    await _context.Database
                        .BeginTransactionAsync(
                            IsolationLevel.Serializable);

                try
                {
                    var client =
                await _context.Clients
                    .FirstOrDefaultAsync(x =>
                        x.UserId ==
                            clientUserId &&
                        !x.IsDeleted);

            if (client == null)
            {
                throw new NotFoundException(
                    "Client not found.");
            }

            var appointment =
    await _context.Appointments
        .Include(x =>
            x.Payment)
        .Include(x =>
            x.Therapist)
        .ThenInclude(x =>
            x.User)
        .FirstOrDefaultAsync(x =>
            x.Id ==
                request.AppointmentId &&
            x.ClientId ==
                client.Id);

            if (appointment == null)
            {
                throw new NotFoundException(
                    "Appointment not found.");
            }

            if (appointment.Status !=
                AppointmentStatus.Accepted)
            {
                throw new Exception(
                    "Membership can only be reserved for an accepted appointment.");
            }

            if (appointment.StartUtc <=
                DateTime.UtcNow)
            {
                throw new BusinessException(
                    "Membership cannot be used for an appointment that has already started.");
            }

            if (appointment.IsPaid)
            {
                throw new BusinessException(
                    "This appointment has already been paid.");
            }

            if (appointment.Payment != null &&
                (appointment.Payment.Status ==
                     PaymentStatus.Paid ||
                 appointment.Payment.Status ==
                     PaymentStatus.RefundPending ||
                 appointment.Payment.Status ==
                     PaymentStatus.Refunded))
            {
                throw new BusinessException(
                    "A Stripe payment already exists for this appointment.");
            }

            var existingUsage =
                await _context.MembershipUsages
                    .FirstOrDefaultAsync(x =>
                        x.AppointmentId ==
                            appointment.Id);

            if (existingUsage != null)
            {
                switch (existingUsage.Status)
                {
                    case MembershipUsageStatus.Reserved:
                        throw new BusinessException(
                            "A membership session is already reserved for this appointment.");

                    case MembershipUsageStatus.Consumed:
                        throw new BusinessException(
                            "A membership session has already been consumed for this appointment.");

                    case MembershipUsageStatus.Restored:
                        throw new Exception(
                            "A previously restored membership session cannot be reserved again for the same appointment.");

                    default:
                        throw new BusinessException(
                            "Membership usage already exists for this appointment.");
                }
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

            remainingSessions =
    membership.RemainingSessions;

            therapistUserId =
                appointment.Therapist.UserId;

            therapistName =
                appointment.Therapist.User.FirstName
                + " "
                + appointment.Therapist.User.LastName;

            if (membership.RemainingSessions == 0)
            {
                membership.IsActive = false;
            }

            var reservedAtUtc =
                DateTime.UtcNow;

            var usage =
                new MembershipUsage
                {
                    ClientMembershipId =
                        membership.Id,

                    AppointmentId =
                        appointment.Id,

                    UsedAtUtc =
                        reservedAtUtc,

                    ReservedAtUtc =
                        reservedAtUtc,

                    Status =
                        MembershipUsageStatus
                            .Reserved,

                    ResolutionReason =
                        "Membership session reserved for an accepted appointment."
                };

            _context.MembershipUsages.Add(
                usage);

            try
            {
                await _context.SaveChangesAsync();

                await transaction.CommitAsync();
            }
            catch (DbUpdateException exception)
            {
                throw new BusinessException(
                    "A membership session has already been reserved for this appointment.",
                    exception);
            }
        }
                catch
                {
                    await transaction.RollbackAsync();

                    throw;
                }
            });

        var correlationId =
      Guid.NewGuid();

        await _integrationEventPublisher
            .PublishAsync(
                new NotificationRequestedEvent
                {
                    CorrelationId =
                        correlationId,

                    TimestampUtc =
                        DateTime.UtcNow,

                    UserId =
                        clientUserId,

                    Title =
                        "Membership session reserved",

                    Message =
                        $"One membership session with "
                        + $"{therapistName} "
                        + "has been reserved for your appointment. "
                        + $"Remaining sessions: {remainingSessions}.",

                    AppointmentId =
                        request.AppointmentId,

                    ActionType =
                        NotificationActionType
                            .Appointment
                            .ToString(),

                    ResourceId =
                        request.AppointmentId,

                    NotificationId =
                        null
                },
                IntegrationEventRoutingKeys
                    .NotificationRequested);

        if (therapistUserId > 0 &&
            therapistUserId != clientUserId)
        {
            await _integrationEventPublisher
                .PublishAsync(
                    new NotificationRequestedEvent
                    {
                        CorrelationId =
                            correlationId,

                        TimestampUtc =
                            DateTime.UtcNow,

                        UserId =
                            therapistUserId,

                        Title =
                            "Membership used for appointment",

                        Message =
                            "A client reserved a membership session "
                            + "for an accepted appointment.",

                        AppointmentId =
                            request.AppointmentId,

                        ActionType =
                            NotificationActionType
                                .Appointment
                                .ToString(),

                        ResourceId =
                            request.AppointmentId,

                        NotificationId =
                            null
                    },
                    IntegrationEventRoutingKeys
                        .NotificationRequested);
        }
    }

    public async Task
    HandleAppointmentCancellationAsync(
        int appointmentId,
        string reason,
        bool forceRestore)
    {
        const int cancellationDeadlineHours =
            24;

        var normalizedReason =
            reason?.Trim() ??
            string.Empty;

        if (normalizedReason.Length > 500)
        {
            normalizedReason =
                normalizedReason[..500];
        }

        var strategy =
    _context.Database
        .CreateExecutionStrategy();

        await strategy.ExecuteAsync(
            async () =>
            {
                await using var transaction =
                    await _context.Database
                        .BeginTransactionAsync(
                            IsolationLevel.Serializable);

                try
                {
                    var usage =
                await _context.MembershipUsages
                    .Include(x =>
                        x.ClientMembership)
                    .Include(x =>
                        x.Appointment)
                    .FirstOrDefaultAsync(x =>
                        x.AppointmentId ==
                            appointmentId);

            if (usage == null)
            {
                await transaction.CommitAsync();

                return;
            }

            if (usage.Status ==
                    MembershipUsageStatus.Restored ||
                usage.Status ==
                    MembershipUsageStatus.Consumed)
            {
                await transaction.CommitAsync();

                return;
            }

            if (usage.Status !=
                MembershipUsageStatus.Reserved)
            {
                throw new Exception(
                    "Membership usage is not in a valid reserved state.");
            }

            var nowUtc =
                DateTime.UtcNow;

            var cancellationDeadlineUtc =
                usage.Appointment.StartUtc
                    .AddHours(
                        -cancellationDeadlineHours);

            var isTimelyCancellation =
                nowUtc <=
                cancellationDeadlineUtc;

            var shouldRestore =
                forceRestore ||
                isTimelyCancellation;

            if (shouldRestore)
            {
                var membership =
                    usage.ClientMembership;

                membership.RemainingSessions =
                    Math.Min(
                        membership.TotalSessions,
                        membership
                            .RemainingSessions +
                        1);

                if (membership.RemainingSessions >
                        0 &&
                    !membership.IsDeleted &&
                    (membership.ExpiresAtUtc ==
                         null ||
                     membership.ExpiresAtUtc >
                         nowUtc))
                {
                    membership.IsActive =
                        true;
                }

                usage.Status =
                    MembershipUsageStatus.Restored;

                usage.RestoredAtUtc =
                    nowUtc;

                usage.ResolutionReason =
                    forceRestore
                        ? $"Session restored because the appointment was rejected or cancelled by the therapist. {normalizedReason}"
                        : $"Session restored because the appointment was cancelled at least {cancellationDeadlineHours} hours before its start. {normalizedReason}";
            }
            else
            {
                usage.Status =
                    MembershipUsageStatus.Consumed;

                usage.ConsumedAtUtc =
                    nowUtc;

                usage.ResolutionReason =
                    $"Session consumed because the appointment was cancelled less than "
                    + $"{cancellationDeadlineHours} hours before its start. "
                    + normalizedReason;
            }

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();
        }
                catch
                {
                    await transaction.RollbackAsync();

                    throw;
                }
            });
    }

    public async Task
    FinalizeAppointmentUsageAsync(
        int appointmentId,
        string reason)
    {
        var normalizedReason =
            reason?.Trim() ??
            string.Empty;

        if (normalizedReason.Length > 500)
        {
            normalizedReason =
                normalizedReason[..500];
        }

        var usage =
            await _context.MembershipUsages
                .FirstOrDefaultAsync(x =>
                    x.AppointmentId ==
                        appointmentId);

        if (usage == null)
        {
            return;
        }

        if (usage.Status ==
                MembershipUsageStatus.Consumed ||
            usage.Status ==
                MembershipUsageStatus.Restored)
        {
            return;
        }

        if (usage.Status !=
            MembershipUsageStatus.Reserved)
        {
            throw new Exception(
                "Membership usage is not in a valid reserved state.");
        }

        usage.Status =
            MembershipUsageStatus.Consumed;

        usage.ConsumedAtUtc =
            DateTime.UtcNow;

        usage.ResolutionReason =
            string.IsNullOrWhiteSpace(
                normalizedReason)
                ? "Membership session consumed after the appointment was completed."
                : normalizedReason;

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
     string description,
     int totalSessions,
     int freeSessions,
     decimal sessionPrice,
     bool isActive)
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

            Description =
                description,

            TotalSessions =
                totalSessions,

            FreeSessions =
                freeSessions,

            Price =
                price,

            PricePerSession =
                totalSessions == 0
                    ? 0
                    : price / totalSessions,

            DurationMonths =
                MembershipDurationMonths,

            IsActive =
                isActive,

            Benefits =
            [
                $"{totalSessions} therapy sessions",
            $"{freeSessions} free "
            + (freeSessions == 1
                ? "session"
                : "sessions"),
            $"{MembershipDurationMonths} months validity",
            "Sessions can be reserved for accepted appointments",
            "A reserved session is restored after a timely cancellation"
            ]
        };
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
        var isExpired =
            membership.ExpiresAtUtc != null &&
            membership.ExpiresAtUtc <=
                DateTime.UtcNow;

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
                membership.PlanType.ToString(),

            PlanName =
                GetPlanName(
                    membership.PlanType),

            TotalSessions =
                membership.TotalSessions,

            RemainingSessions =
                membership.RemainingSessions,

            UsedSessions =
                Math.Max(
                    0,
                    membership.TotalSessions -
                    membership.RemainingSessions),

            Price =
                membership.Price,

            IsActive =
                membership.IsActive &&
                !isExpired &&
                membership.RemainingSessions > 0,

            IsPaid =
                payment?.Status ==
                    PaymentStatus.Paid,

            IsExpired =
                isExpired,

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

    private static bool IsPlanActive(
    MembershipPlanType planType)
    {
        return planType is
            MembershipPlanType.TenSessions or
            MembershipPlanType.TwentySessions or
            MembershipPlanType.ThirtySessions;
    }

    private static string GetPlanDescription(
        MembershipPlanType planType)
    {
        return planType switch
        {
            MembershipPlanType.TenSessions =>
                "A starter package for regular therapy sessions.",

            MembershipPlanType.TwentySessions =>
                "A larger package for continued therapeutic work.",

            MembershipPlanType.ThirtySessions =>
                "The largest package with the highest included benefit.",

            _ =>
                "Membership package"
        };
    }

    private static List<string>
    DeserializeBenefits(
        string? benefitsJson)
    {
        if (string.IsNullOrWhiteSpace(
                benefitsJson))
        {
            return [];
        }

        try
        {
            return System.Text.Json.JsonSerializer
                .Deserialize<List<string>>(
                    benefitsJson)
                ?? [];
        }
        catch (System.Text.Json.JsonException)
        {
            return [];
        }
    }

    private static int CalculateFreeSessions(
        int totalSessions,
        decimal discountPercentage)
    {
        if (totalSessions <= 0
            || discountPercentage <= 0)
        {
            return 0;
        }

        return (int)Math.Round(
            totalSessions
            * discountPercentage
            / 100m,
            MidpointRounding.AwayFromZero);
    }
}