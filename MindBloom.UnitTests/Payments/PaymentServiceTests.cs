using System.Runtime.CompilerServices;
using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Payments;

public sealed class PaymentServiceTests
{
    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenClientDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.CreatePaymentIntentAsync(
                    999,
                    new CreatePaymentIntentDto
                    {
                        AppointmentId =
                            1
                    }));
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenAppointmentDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.CreatePaymentIntentAsync(
                    client.UserId,
                    new CreatePaymentIntentDto
                    {
                        AppointmentId =
                            999
                    }));
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenAppointmentBelongsToAnotherClient_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var owner =
            await SeedClientAsync(
                context,
                "owner@test.local");

        var otherClient =
            await SeedClientAsync(
                context,
                "other@test.local");

        var therapist =
            await SeedTherapistAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                owner.Id,
                therapist.Id,
                AppointmentStatus.Accepted);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            BusinessException>(
            () =>
                service.CreatePaymentIntentAsync(
                    otherClient.UserId,
                    new CreatePaymentIntentDto
                    {
                        AppointmentId =
                            appointment.Id
                    }));
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenAppointmentIsPending_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Pending);

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.CreatePaymentIntentAsync(
                        client.UserId,
                        new CreatePaymentIntentDto
                        {
                            AppointmentId =
                                appointment.Id
                        }));

        Assert.Equal(
            "Only accepted appointments can be paid.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenAppointmentIsAlreadyPaid_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Accepted,
                isPaid: true);

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.CreatePaymentIntentAsync(
                        client.UserId,
                        new CreatePaymentIntentDto
                        {
                            AppointmentId =
                                appointment.Id
                        }));

        Assert.Equal(
            "This appointment is already paid.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenExistingPaymentIsPaid_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Accepted);

        context.Payments.Add(
            new Payment
            {
                AppointmentId =
                    appointment.Id,

                Amount =
                    50m,

                Status =
                    PaymentStatus.Paid,

                StripePaymentIntentId =
                    "pi_unit_paid",

                PaidAtUtc =
                    DateTime.UtcNow
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.CreatePaymentIntentAsync(
                        client.UserId,
                        new CreatePaymentIntentDto
                        {
                            AppointmentId =
                                appointment.Id
                        }));

        Assert.Equal(
            "Appointment has already been paid.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenExistingPaymentWasRefunded_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Accepted);

        context.Payments.Add(
            new Payment
            {
                AppointmentId =
                    appointment.Id,

                Amount =
                    50m,

                Status =
                    PaymentStatus.Refunded,

                StripePaymentIntentId =
                    "pi_unit_refunded"
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.CreatePaymentIntentAsync(
                        client.UserId,
                        new CreatePaymentIntentDto
                        {
                            AppointmentId =
                                appointment.Id
                        }));

        Assert.Equal(
            "Refunded appointments require a new booking.",
            exception.Message);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task
        RefundAppointmentPaymentAsync_WhenReasonIsMissing_ThrowsBusinessException(
            string? reason)
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service
                        .RefundAppointmentPaymentAsync(
                            1,
                            1,
                            reason!));

        Assert.Equal(
            "Refund reason is required.",
            exception.Message);
    }

    [Fact]
    public async Task
        RefundAppointmentPaymentAsync_WhenReasonExceedsMaximumLength_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        var reason =
            new string(
                'a',
                501);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service
                        .RefundAppointmentPaymentAsync(
                            1,
                            1,
                            reason));

        Assert.Equal(
            "Refund reason may contain at most 500 characters.",
            exception.Message);
    }

    [Fact]
    public async Task
        GetReceiptAsync_WhenClientDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.GetReceiptAsync(
                    1,
                    999));
    }

    [Fact]
    public async Task
        GetReceiptAsync_WhenPaymentBelongsToAnotherClient_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var owner =
            await SeedClientAsync(
                context,
                "owner@test.local");

        var other =
            await SeedClientAsync(
                context,
                "other@test.local");

        var therapist =
            await SeedTherapistAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                owner.Id,
                therapist.Id,
                AppointmentStatus.Accepted);

        var payment =
            new Payment
            {
                AppointmentId =
                    appointment.Id,

                Amount =
                    50m,

                Status =
                    PaymentStatus.Paid,

                StripePaymentIntentId =
                    "pi_receipt",

                PaidAtUtc =
                    DateTime.UtcNow
            };

        context.Payments.Add(
            payment);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.GetReceiptAsync(
                    payment.Id,
                    other.UserId));
    }

    private static PaymentService
        CreateService(
            ApplicationDbContext context)
    {
        /*
         * Ovi unit testovi namjerno testiraju
         * grane prije Stripe poziva.
         *
         * Zato concrete StripeVerificationService
         * ne treba stvarnu mrežnu konfiguraciju.
         */
        var stripeVerificationService =
            (StripeVerificationService)
            RuntimeHelpers
                .GetUninitializedObject(
                    typeof(
                        StripeVerificationService));

        var notificationService =
            new Mock<
                IBusinessNotificationService>();

        var publisher =
            new Mock<
                IIntegrationEventPublisher>();

        var outbox =
            new Mock<
                IOutboxWriter>();

        return new PaymentService(
            context,
            stripeVerificationService,
            notificationService.Object,
            publisher.Object,
            outbox.Object);
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"payment-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static async Task<Client>
        SeedClientAsync(
            ApplicationDbContext context,
            string email =
                "client@test.local")
    {
        var user =
            CreateUser(
                email,
                "Test",
                "Client");

        context.Users.Add(
            user);

        await context.SaveChangesAsync();

        var client =
            new Client
            {
                UserId =
                    user.Id
            };

        context.Clients.Add(
            client);

        await context.SaveChangesAsync();

        return client;
    }

    private static async Task<Therapist>
        SeedTherapistAsync(
            ApplicationDbContext context)
    {
        var user =
            CreateUser(
                $"therapist-{Guid.NewGuid():N}@test.local",
                "Test",
                "Therapist");

        context.Users.Add(
            user);

        await context.SaveChangesAsync();

        var therapist =
            new Therapist
            {
                UserId =
                    user.Id,

                Biography =
                    "Unit test",

                Specialization =
                    "Psychotherapy",

                PricePerSession =
                    50m,

                HourlyRate =
                    50m,

                ExperienceYears =
                    5,

                Country =
                    "Bosnia and Herzegovina",

                City =
                    "Mostar",

                Address =
                    "Test",

                Education =
                    "Test"
            };

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist;
    }

    private static async Task<Appointment>
        SeedAppointmentAsync(
            ApplicationDbContext context,
            int clientId,
            int therapistId,
            AppointmentStatus status,
            bool isPaid = false)
    {
        var start =
            DateTime.UtcNow
                .AddDays(2);

        var appointment =
            new Appointment
            {
                ClientId =
                    clientId,

                TherapistId =
                    therapistId,

                AppointmentDateUtc =
                    start,

                StartUtc =
                    start,

                EndUtc =
                    start.AddHours(1),

                Status =
                    status,

                Price =
                    50m,

                IsPaid =
                    isPaid,

                Type =
                    AppointmentType.Online
            };

        context.Appointments.Add(
            appointment);

        await context.SaveChangesAsync();

        return appointment;
    }

    private static ApplicationUser
        CreateUser(
            string email,
            string firstName,
            string lastName)
    {
        return new ApplicationUser
        {
            UserName =
                email,

            Email =
                email,

            FirstName =
                firstName,

            LastName =
                lastName,

            IsActive =
                true,

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }
}