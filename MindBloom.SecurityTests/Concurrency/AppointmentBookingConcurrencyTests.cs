using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Messaging.Outbox;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Shared.Observability;
using Xunit;

namespace MindBloom.SecurityTests.Concurrency;

public sealed class AppointmentBookingConcurrencyTests
{
    [Fact]
    [Trait(
        "Category",
        "SqlServerConcurrency")]
    public async Task
        CreateAsync_WhenTwoClientsBookSameSlotConcurrently_OnlyOneAppointmentIsCreated()
    {
        var baseConnectionString =
            Environment.GetEnvironmentVariable(
                "TEST_SQL_CONNECTION")
            ??
            Environment.GetEnvironmentVariable(
                "DB_CONNECTION");

        if (string.IsNullOrWhiteSpace(
                baseConnectionString))
        {
            throw new InvalidOperationException(
                "TEST_SQL_CONNECTION or DB_CONNECTION "
                + "must be configured to run SQL Server "
                + "concurrency tests.");
        }

        var databaseName =
            $"MindBloomConcurrencyTests_"
            + $"{Guid.NewGuid():N}";

        var connectionBuilder =
            new SqlConnectionStringBuilder(
                baseConnectionString)
            {
                InitialCatalog =
                    databaseName
            };

        var testConnectionString =
            connectionBuilder
                .ConnectionString;

        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseSqlServer(
                    testConnectionString)
                .Options;

        try
        {
            await InitializeDatabaseAsync(
                options);

            var seeded =
                await SeedBookingScenarioAsync(
                    options);

            /*
             * Svaki paralelni request dobija
             * zaseban DbContext, isto kao dva
             * stvarna HTTP requesta.
             */
            await using var firstContext =
                new ApplicationDbContext(
                    options);

            await using var secondContext =
                new ApplicationDbContext(
                    options);

            var firstService =
                CreateAppointmentService(
                    firstContext);

            var secondService =
                CreateAppointmentService(
                    secondContext);

            var request =
                new CreateAppointmentDto
                {
                    TherapistId =
                        seeded.TherapistId,

                    StartUtc =
                        seeded.StartUtc,

                    EndUtc =
                        seeded.EndUtc,

                    Type =
                        (AppointmentType)1,

                    MeetingLink =
                        null,

                    Location =
                        null,

                    Notes =
                        "Concurrency test booking."
                };

            /*
             * Gate osigurava da oba pokušaja
             * krenu praktično istovremeno.
             */
            var startGate =
                new TaskCompletionSource<bool>(
                    TaskCreationOptions
                        .RunContinuationsAsynchronously);

            var firstAttempt =
                RunBookingAttemptAsync(
                    startGate.Task,
                    firstService,
                    seeded.FirstClientUserId,
                    request);

            var secondAttempt =
                RunBookingAttemptAsync(
                    startGate.Task,
                    secondService,
                    seeded.SecondClientUserId,
                    request);

            startGate.SetResult(
                true);

            var results =
                await Task.WhenAll(
                    firstAttempt,
                    secondAttempt);

            var successfulAttempts =
                results.Count(
                    result =>
                        result.Succeeded);

            var failedAttempts =
                results.Where(
                        result =>
                            !result.Succeeded)
                    .ToList();

            /*
             * Tačno jedan request smije
             * uspješno rezervisati slot.
             */
            Assert.Equal(
                1,
                successfulAttempts);

            Assert.Single(
                failedAttempts);

            /*
             * Drugi request mora dobiti
             * poslovni conflict, ne smije
             * napraviti drugi Appointment.
             */
            var failure =
                failedAttempts.Single()
                    .Exception;

            Assert.NotNull(
                failure);

            Assert.IsType<
                BusinessException>(
                failure);

            Assert.Contains(
                "already been booked",
                failure!.Message,
                StringComparison
                    .OrdinalIgnoreCase);

            /*
             * Najvažnija DB provjera:
             * bez obzira na dva paralelna
             * requesta u tabeli mora ostati
             * samo jedan aktivni termin
             * za ovaj slot.
             */
            await using var verificationContext =
                new ApplicationDbContext(
                    options);

            var appointments =
                await verificationContext
                    .Appointments
                    .AsNoTracking()
                    .Where(appointment =>
                        appointment.TherapistId ==
                            seeded.TherapistId &&
                        appointment.StartUtc ==
                            seeded.StartUtc &&
                        appointment.EndUtc ==
                            seeded.EndUtc &&
                        (
                            appointment.Status ==
                                AppointmentStatus
                                    .Pending ||
                            appointment.Status ==
                                AppointmentStatus
                                    .Accepted
                        ))
                    .ToListAsync();

            Assert.Single(
                appointments);

            /*
             * Provjeravamo i da winner
             * pripada jednom od dva
             * klijenta koja su slala request.
             */
            var clientIds =
                new[]
                {
                    seeded.FirstClientId,
                    seeded.SecondClientId
                };

            Assert.Contains(
                appointments.Single()
                    .ClientId,
                clientIds);
        }
        finally
        {
            await DeleteDatabaseAsync(
                options);
        }
    }

    private static AppointmentService
        CreateAppointmentService(
            ApplicationDbContext context)
    {
        var paymentService =
            new Mock<IPaymentService>();

        var membershipService =
            new Mock<IMembershipService>();

        var integrationEventPublisher =
            new Mock<
                IIntegrationEventPublisher>();

        var correlationIdAccessor =
            new Mock<
                ICorrelationIdAccessor>();

        correlationIdAccessor
            .Setup(accessor =>
                accessor.CorrelationId)
            .Returns(
                Guid.NewGuid()
                    .ToString());

        /*
         * Koristimo pravi OutboxWriter,
         * tako da Appointment + Outbox
         * prolaze kroz stvarni DbContext
         * transaction.
         */
        var outboxWriter =
            new OutboxWriter(
                context,
                correlationIdAccessor.Object);

        var applicationMetrics =
            new ApplicationMetrics();

        return new AppointmentService(
            context,
            paymentService.Object,
            membershipService.Object,
            applicationMetrics,
            integrationEventPublisher.Object,
            outboxWriter);
    }

    private static async Task<
        BookingAttemptResult>
        RunBookingAttemptAsync(
            Task startGate,
            AppointmentService service,
            int clientUserId,
            CreateAppointmentDto request)
    {
        await startGate;

        try
        {
            await service.CreateAsync(
                clientUserId,
                new CreateAppointmentDto
                {
                    TherapistId =
                        request.TherapistId,

                    StartUtc =
                        request.StartUtc,

                    EndUtc =
                        request.EndUtc,

                    Type =
                        request.Type,

                    MeetingLink =
                        request.MeetingLink,

                    Location =
                        request.Location,

                    Notes =
                        request.Notes
                });

            return new BookingAttemptResult(
                true,
                null);
        }
        catch (Exception exception)
        {
            return new BookingAttemptResult(
                false,
                exception);
        }
    }

    private static async Task
        InitializeDatabaseAsync(
            DbContextOptions<
                ApplicationDbContext>
                options)
    {
        await using var context =
            new ApplicationDbContext(
                options);

        /*
         * Koristimo stvarne migracije,
         * uključujući migration iz Taska 161.
         */
        await context.Database
            .MigrateAsync();
    }

    private static async Task<
    BookingScenario>
    SeedBookingScenarioAsync(
        DbContextOptions<
            ApplicationDbContext>
            options)
    {
        await using var context =
            new ApplicationDbContext(
                options);

        /*
         * 1. USERS
         */
        var firstClientUser =
            CreateUser(
                "concurrency-client-1");

        var secondClientUser =
            CreateUser(
                "concurrency-client-2");

        var therapistUser =
            CreateUser(
                "concurrency-therapist");

        context.Users.AddRange(
            firstClientUser,
            secondClientUser,
            therapistUser);

        await context.SaveChangesAsync();

        /*
         * Namjerno ponovo čitamo ID-eve iz SQL baze.
         * Tako test ne može slučajno koristiti
         * stari hardkodirani ili nepersistirani ID.
         */
        var firstClientUserId =
            await context.Users
                .Where(user =>
                    user.Email ==
                    "concurrency-client-1@mindbloom.test")
                .Select(user =>
                    user.Id)
                .SingleAsync();

        var secondClientUserId =
            await context.Users
                .Where(user =>
                    user.Email ==
                    "concurrency-client-2@mindbloom.test")
                .Select(user =>
                    user.Id)
                .SingleAsync();

        var therapistUserId =
            await context.Users
                .Where(user =>
                    user.Email ==
                    "concurrency-therapist@mindbloom.test")
                .Select(user =>
                    user.Id)
                .SingleAsync();

        /*
         * 2. THERAPIST SPECIALIZATION
         */
        var specialization =
            new TherapistSpecialization
            {
                Name =
                    $"Concurrency specialization "
                    + $"{Guid.NewGuid():N}",

                Description =
                    "Specialization used only for "
                    + "appointment concurrency tests.",

                IsActive =
                    true
            };

        context.TherapistSpecializations.Add(
            specialization);

        await context.SaveChangesAsync();

        /*
         * 3. CLIENT + THERAPIST PROFILES
         */
        var firstClient =
            new Client
            {
                UserId =
                    firstClientUserId,

                HasCompletedOnboarding =
                    true
            };

        var secondClient =
            new Client
            {
                UserId =
                    secondClientUserId,

                HasCompletedOnboarding =
                    true
            };

        var therapist =
            new Therapist
            {
                UserId =
                    therapistUserId,

                SpecializationId =
                    specialization.Id,

                Biography =
                    "Concurrency test therapist.",

                Specialization =
                    "Concurrency testing",

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
                    "Concurrency test address",

                Education =
                    "Concurrency test education",

                OffersOnline =
                    true,

                OffersInPerson =
                    true
            };

        context.Clients.AddRange(
            firstClient,
            secondClient);

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        /*
         * 4. AVAILABLE SLOT
         */
        var startUtc =
            DateTime.UtcNow
                .Date
                .AddDays(7)
                .AddHours(10);

        var endUtc =
            startUtc.AddHours(1);

        context.TherapistAvailabilities.Add(
            new TherapistAvailability
            {
                TherapistId =
                    therapist.Id,

                DayOfWeek =
                    startUtc.DayOfWeek,

                StartTime =
                    new TimeSpan(
                        8,
                        0,
                        0),

                EndTime =
                    new TimeSpan(
                        18,
                        0,
                        0)
            });

        await context.SaveChangesAsync();

        return new BookingScenario(
            firstClientUserId,
            secondClientUserId,
            firstClient.Id,
            secondClient.Id,
            therapist.Id,
            startUtc,
            endUtc);
    }

    private static ApplicationUser
    CreateUser(
        string username)
    {
        var email =
            $"{username}@mindbloom.test";

        return new ApplicationUser
        {

            FirstName =
                "Concurrency",

            LastName =
                "Test",

            Email =
                email,

            NormalizedEmail =
                email.ToUpperInvariant(),

            UserName =
                username,

            NormalizedUserName =
                username.ToUpperInvariant(),

            EmailConfirmed =
                true,

            IsEmailVerified =
                true,

            IsActive =
                true,

            IsBlocked =
                false,

            LockoutEnabled =
                true,

            AccessFailedCount =
                0,

            DateOfBirth =
                new DateTime(
                    1995,
                    1,
                    1),

            Gender =
                "Other",

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }

    private static async Task
        DeleteDatabaseAsync(
            DbContextOptions<
                ApplicationDbContext>
                options)
    {
        try
        {
            await using var context =
                new ApplicationDbContext(
                    options);

            await context.Database
                .EnsureDeletedAsync();
        }
        catch
        {
        }
    }

    private sealed record
        BookingAttemptResult(
            bool Succeeded,
            Exception? Exception);

    private sealed record
        BookingScenario(
            int FirstClientUserId,
            int SecondClientUserId,
            int FirstClientId,
            int SecondClientId,
            int TherapistId,
            DateTime StartUtc,
            DateTime EndUtc);
}