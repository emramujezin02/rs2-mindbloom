using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.IntegrationTests.Infrastructure;

public sealed class MindBloomIntegrationTestFactory
    : WebApplicationFactory<Program>
{
    private readonly string _databaseName =
        $"MindBloomIntegrationTests-"
        + $"{Guid.NewGuid():N}";

    public MindBloomIntegrationTestFactory()
    {
        ConfigureTestEnvironment();
    }

    protected override void ConfigureWebHost(
        IWebHostBuilder builder)
    {
        builder.UseEnvironment(
            "Testing");

        builder.ConfigureAppConfiguration(
     (_, configuration) =>
     {
         configuration.AddInMemoryCollection(
             new Dictionary<
                 string,
                 string?>
             {
                 ["RABBITMQ_HOST"] =
                     "localhost",

                 ["RABBITMQ_PORT"] =
                     "5672",

                 ["RABBITMQ_USERNAME"] =
                     "integration-tests",

                 ["RABBITMQ_USER"] =
                     "integration-tests",

                 ["RABBITMQ_PASSWORD"] =
                     "integration-tests",

                 ["RABBITMQ_VIRTUAL_HOST"] =
                     "/",

                 ["RABBITMQ_CLIENT_NAME"] =
                     "mindbloom-integration-tests",

                 ["RABBITMQ_WORKER_CLIENT_NAME"] =
                     "mindbloom-integration-tests-worker",

                 ["RABBITMQ_NOTIFICATION_EXCHANGE"] =
                     "mindbloom.integration-tests",

                 ["RABBITMQ_EXCHANGE"] =
                     "mindbloom.integration-tests",

                 ["RABBITMQ_EMAIL_QUEUE"] =
                     "mindbloom.integration-tests.email",

                 ["RABBITMQ_EMAIL_ROUTING_KEY"] =
                     "notification.email",

                 ["RABBITMQ_RETRY_EXCHANGE"] =
                     "mindbloom.integration-tests.retry",

                 ["RABBITMQ_DEAD_LETTER_EXCHANGE"] =
                     "mindbloom.integration-tests.dead-letter",

                 ["RABBITMQ_EMAIL_DEAD_LETTER_QUEUE"] =
                     "mindbloom.integration-tests.email.dead-letter",

                 ["RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY"] =
                     "notification.email.dead",

                 ["RABBITMQ_PREFETCH_COUNT"] =
                     "1",

                 ["RABBITMQ_MAXIMUM_RETRY_COUNT"] =
                     "4",

                 ["RABBITMQ_AUTOMATIC_RECOVERY"] =
                     "true",

                 ["RABBITMQ_RECOVERY_INTERVAL_SECONDS"] =
                     "5",

                 ["RABBITMQ_HEARTBEAT_SECONDS"] =
                     "30",

                 ["RABBITMQ_CONNECTION_RETRY_COUNT"] =
                     "5",

                 ["RABBITMQ_INTEGRATION_EVENT_QUEUE"] =
                     "mindbloom.integration-tests.integration-events",

                 ["RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_QUEUE"] =
                     "mindbloom.integration-tests.integration-events.dlq",

                 ["RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_ROUTING_KEY"] =
                     "integration-event.dead",

                 ["RABBITMQ_DLQ_MONITORING_INTERVAL_SECONDS"] =
                     "60",

                 ["RABBITMQ_DLQ_WARNING_MESSAGE_COUNT"] =
                     "1",

                 ["RABBITMQ_CONNECTION_RETRY_DELAY_SECONDS"] =
                     "3",

                 ["RABBITMQ_MONITORING_INTERVAL_SECONDS"] =
                     "60"
             });
     });

        builder.ConfigureServices(
            services =>
            {
                services.RemoveAll<
                    DbContextOptions<
                        ApplicationDbContext>>();

                services.RemoveAll<
                    IDbContextOptionsConfiguration<
                        ApplicationDbContext>>();

                services.AddDbContext<
                    ApplicationDbContext>(
                    options =>
                    {
                        options.UseInMemoryDatabase(
                            _databaseName);
                    });

                var hostedServices =
                    services
                        .Where(descriptor =>
                            descriptor.ServiceType ==
                            typeof(IHostedService))
                        .ToList();

                foreach (var descriptor
                         in hostedServices)
                {
                    services.Remove(
                        descriptor);
                }

                services
                    .AddAuthentication(
                        options =>
                        {
                            options.DefaultScheme =
                                TestAuthenticationHandler
                                    .SchemeName;

                            options
                                .DefaultAuthenticateScheme =
                                TestAuthenticationHandler
                                    .SchemeName;

                            options
                                .DefaultChallengeScheme =
                                TestAuthenticationHandler
                                    .SchemeName;
                        })
                    .AddScheme<
                        AuthenticationSchemeOptions,
                        TestAuthenticationHandler>(
                        TestAuthenticationHandler
                            .SchemeName,
                        _ =>
                        {
                        });

                services.RemoveAll<
    INotificationPublisher>();

                services.AddSingleton<
                    TestNotificationPublisher>();

                services.AddSingleton<
                    INotificationPublisher>(
                    serviceProvider =>
                        serviceProvider
                            .GetRequiredService<
                                TestNotificationPublisher>()); services.RemoveAll<
    INotificationPublisher>();

                services.AddSingleton<
                    TestNotificationPublisher>();

                services.AddSingleton<
                    INotificationPublisher>(
                    serviceProvider =>
                        serviceProvider
                            .GetRequiredService<
                                TestNotificationPublisher>());
            });
    }

    private static void
        ConfigureTestEnvironment()
    {
        Environment.SetEnvironmentVariable(
            "ASPNETCORE_ENVIRONMENT",
            "Testing");

        Environment.SetEnvironmentVariable(
            "DOTNET_ENVIRONMENT",
            "Testing");

        Environment.SetEnvironmentVariable(
            "DB_CONNECTION",
            "Server=localhost;"
            + "Database=MindBloomIntegrationTests;"
            + "User Id=test;"
            + "Password=TestOnlyPassword123!;"
            + "TrustServerCertificate=True;"
            + "Encrypt=False;");

        Environment.SetEnvironmentVariable(
            "JWT_SECRET",
            "MindBloom.IntegrationTests."
            + "JWT.Secret.2026."
            + "Only.For.Automated.Tests!");

        Environment.SetEnvironmentVariable(
            "JWT_ISSUER",
            "MindBloom.IntegrationTests");

        Environment.SetEnvironmentVariable(
            "JWT_AUDIENCE",
            "MindBloom.IntegrationTests.Client");

        Environment.SetEnvironmentVariable(
            "JWT_EXPIRATION_MINUTES",
            "15");

        Environment.SetEnvironmentVariable(
            "STRIPE_SECRET_KEY",
            "sk_test_integration_tests_only");

        Environment.SetEnvironmentVariable(
            "STRIPE_WEBHOOK_SECRET",
            "whsec_integration_tests_only");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_HOST",
            "localhost");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_PORT",
            "5672");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_USERNAME",
            "integration-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_USER",
            "integration-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_PASSWORD",
            "integration-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_VIRTUAL_HOST",
            "/");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_CLIENT_NAME",
            "mindbloom-integration-tests");

        Environment.SetEnvironmentVariable(
    "RABBITMQ_WORKER_CLIENT_NAME",
    "mindbloom-integration-tests-worker");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_NOTIFICATION_EXCHANGE",
            "mindbloom.integration-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EMAIL_QUEUE",
            "mindbloom.integration-tests.email");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EMAIL_ROUTING_KEY",
            "notification.email");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_RETRY_EXCHANGE",
            "mindbloom.integration-tests.retry");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_DEAD_LETTER_EXCHANGE",
            "mindbloom.integration-tests.dead-letter");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EMAIL_DEAD_LETTER_QUEUE",
            "mindbloom.integration-tests.email.dead-letter");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY",
            "notification.email.dead");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_PREFETCH_COUNT",
            "1");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_MAXIMUM_RETRY_COUNT",
            "4");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_AUTOMATIC_RECOVERY",
            "true");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_RECOVERY_INTERVAL_SECONDS",
            "5");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_HEARTBEAT_SECONDS",
            "30");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_CONNECTION_RETRY_COUNT",
            "5");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_INTEGRATION_EVENT_QUEUE",
            "mindbloom.integration-tests.integration-events");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_QUEUE",
            "mindbloom.integration-tests.integration-events.dlq");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_ROUTING_KEY",
            "integration-event.dead");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_DLQ_MONITORING_INTERVAL_SECONDS",
            "60");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_DLQ_WARNING_MESSAGE_COUNT",
            "1");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_CONNECTION_RETRY_DELAY_SECONDS",
            "3");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_MONITORING_INTERVAL_SECONDS",
            "60");
    }

    public HttpClient CreateAuthenticatedClient(
        int userId,
        string role,
        string? email = null)
    {
        var client =
            CreateClient();

        client.DefaultRequestHeaders.Add(
            TestAuthenticationHandler
                .UserIdHeader,
            userId.ToString());

        client.DefaultRequestHeaders.Add(
            TestAuthenticationHandler
                .RoleHeader,
            role);

        client.DefaultRequestHeaders.Add(
            TestAuthenticationHandler
                .EmailHeader,
            email ??
            $"integration-{userId}@mindbloom.test");

        return client;
    }

    public async Task SeedActiveUserAsync(
        int userId,
        string role,
        string email,
        string password)
    {
        using var scope =
            Services.CreateScope();

        var userManager =
            scope.ServiceProvider
                .GetRequiredService<
                    UserManager<
                        ApplicationUser>>();

        var roleManager =
            scope.ServiceProvider
                .GetRequiredService<
                    RoleManager<
                        IdentityRole<int>>>();

        var existing =
            await userManager.FindByIdAsync(
                userId.ToString());

        if (existing != null)
        {
            return;
        }

        if (!await roleManager
                .RoleExistsAsync(role))
        {
            var roleResult =
                await roleManager.CreateAsync(
                    new IdentityRole<int>
                    {
                        Name = role
                    });

            if (!roleResult.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(
                        "; ",
                        roleResult.Errors
                            .Select(x =>
                                x.Description)));
            }
        }

        var user =
            new ApplicationUser
            {
                Id = userId,

                FirstName =
                    "Integration",

                LastName =
                    "Test",

                Email =
                    email,

                UserName =
                    $"integration-test-{userId}",

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

        var createResult =
            await userManager.CreateAsync(
                user,
                password);

        if (!createResult.Succeeded)
        {
            throw new InvalidOperationException(
                string.Join(
                    "; ",
                    createResult.Errors
                        .Select(x =>
                            x.Description)));
        }

        var addRoleResult =
            await userManager.AddToRoleAsync(
                user,
                role);

        if (!addRoleResult.Succeeded)
        {
            throw new InvalidOperationException(
                string.Join(
                    "; ",
                    addRoleResult.Errors
                        .Select(x =>
                            x.Description)));
        }
    }

    public async Task<int>
        SeedClientProfileAsync(
            int userId)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var existing =
            await context.Clients
                .FirstOrDefaultAsync(
                    x =>
                        x.UserId ==
                        userId);

        if (existing != null)
        {
            return existing.Id;
        }

        var client =
            new Client
            {
                UserId =
                    userId,

                HasCompletedOnboarding =
                    true
            };

        context.Clients.Add(
            client);

        await context.SaveChangesAsync();

        return client.Id;
    }

    public async Task<int>
        SeedTherapistProfileAsync(
            int userId)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var existing =
            await context.Therapists
                .FirstOrDefaultAsync(
                    x =>
                        x.UserId ==
                        userId);

        if (existing != null)
        {
            return existing.Id;
        }

        var therapist =
            new Therapist
            {
                UserId =
                    userId,

                Biography =
                    "Integration test therapist.",

                Specialization =
                    "Integration testing",

                PricePerSession =
                    50m,

                HourlyRate =
                    50m,

                ExperienceYears =
                    5,

                VerificationStatus =
                    MindBloom.Domain.Enums
                        .TherapistVerificationStatus
                        .Approved,

                Country =
                    "Bosnia and Herzegovina",

                City =
                    "Mostar",

                Address =
                    "Integration test address",

                Education =
                    "Integration test education",

                OffersOnline =
                    true
            };

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist.Id;
    }

    public async Task<int> SeedAppointmentAsync(
    int clientId,
    int therapistId,
    MindBloom.Domain.Enums.AppointmentStatus status,
    bool isPaid = false)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var startUtc =
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
                    startUtc,

                StartUtc =
                    startUtc,

                EndUtc =
                    startUtc.AddHours(1),

                Status =
                    status,

                Price =
                    50m,

                IsPaid =
                    isPaid,

                Type =
                    MindBloom.Domain.Enums
                        .AppointmentType.Online
            };

        context.Appointments.Add(
            appointment);

        await context.SaveChangesAsync();

        return appointment.Id;
    }

    public async Task<int> SeedPaymentAsync(
        int appointmentId,
        MindBloom.Domain.Enums.PaymentStatus status)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var payment =
            new Payment
            {
                AppointmentId =
                    appointmentId,

                Amount =
                    50m,

                Status =
                    status,

                StripePaymentIntentId =
                    $"pi_integration_{Guid.NewGuid():N}",

                PaidAtUtc =
                    status ==
                    MindBloom.Domain.Enums.PaymentStatus.Paid
                        ? DateTime.UtcNow
                        : null
            };

        context.Payments.Add(
            payment);

        await context.SaveChangesAsync();

        return payment.Id;
    }

    public async Task<int> SeedMembershipPlanAsync(
        MindBloom.Domain.Enums.MembershipPlanType planType =
            MindBloom.Domain.Enums.MembershipPlanType.TenSessions,
        bool isActive = true)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var plan =
            new MembershipPlan
            {
                Name =
                    "Integration plan",

                Description =
                    "Integration test membership plan.",

                PlanType =
                    planType,

                Price =
                    400m,

                DurationMonths =
                    6,

                IncludedSessions =
                    10,

                DiscountPercentage =
                    0m,

                BenefitsJson =
                    "[]",

                IsActive =
                    isActive
            };

        context.MembershipPlans.Add(
            plan);

        await context.SaveChangesAsync();

        return plan.Id;
    }

    public async Task<int> SeedClientMembershipAsync(
        int clientId,
        int therapistId,
        bool isActive = true,
        int remainingSessions = 5)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var membership =
            new ClientMembership
            {
                ClientId =
                    clientId,

                TherapistId =
                    therapistId,

                PlanType =
                    MindBloom.Domain.Enums
                        .MembershipPlanType
                        .TenSessions,

                TotalSessions =
                    10,

                RemainingSessions =
                    remainingSessions,

                Price =
                    400m,

                DurationMonths =
                    6,

                IsActive =
                    isActive,

                PurchasedAtUtc =
                    DateTime.UtcNow
                        .AddDays(-10),

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddMonths(5)
            };

        context.ClientMemberships.Add(
            membership);

        await context.SaveChangesAsync();

        return membership.Id;
    }

    public async Task<int> SeedReviewAsync(
        int clientId,
        int therapistId,
        int appointmentId,
        bool approved = true)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var review =
            new Review
            {
                ClientId =
                    clientId,

                TherapistId =
                    therapistId,

                AppointmentId =
                    appointmentId,

                Rating =
                    5,

                Comment =
                    "Integration test review.",

                IsApproved =
                    approved,

                ModerationStatus =
                    approved
                        ? MindBloom.Domain.Enums
                            .ReviewModerationStatus.Approved
                        : MindBloom.Domain.Enums
                            .ReviewModerationStatus.Pending
            };

        context.Reviews.Add(
            review);

        await context.SaveChangesAsync();

        return review.Id;
    }

    public async Task<int> SeedWorkshopAsync(
        int organizerUserId,
        int capacity = 10,
        MindBloom.Domain.Enums.WorkshopStatus status =
            MindBloom.Domain.Enums.WorkshopStatus.Scheduled)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var startUtc =
            DateTime.UtcNow
                .AddDays(5);

        var workshop =
            new Workshop
            {
                Title =
                    "Integration Workshop",

                Description =
                    "Workshop for API integration tests.",

                StartUtc =
                    startUtc,

                EndUtc =
                    startUtc.AddHours(2),

                Type =
                    MindBloom.Domain.Enums
                        .WorkshopType.Online,

                OnlineLink =
                    "https://example.test/workshop",

                Capacity =
                    capacity,

                Price =
                    20m,

                Status =
                    status,

                OrganizerUserId =
                    organizerUserId,

                RegistrationDeadlineUtc =
                    DateTime.UtcNow
                        .AddDays(3)
            };

        context.Workshops.Add(
            workshop);

        await context.SaveChangesAsync();

        return workshop.Id;
    }

    public string GetIdempotencyHeaderName()
    {
        using var scope =
            Services.CreateScope();

        var options =
            scope.ServiceProvider
                .GetRequiredService<
                    IOptions<IdempotencyOptions>>();

        return options.Value.HeaderName;
    }

    public async Task SeedCompletedIdempotencyRecordAsync(
        string idempotencyKey,
        int userId,
        string operation,
        object actionArguments,
        int responseStatusCode,
        string? responseBody)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var requestHash =
            CreateIdempotencyRequestHash(
                operation,
                actionArguments);

        context.ApiIdempotencyRecords.Add(
            new ApiIdempotencyRecord
            {
                IdempotencyKey =
                    idempotencyKey,

                UserId =
                    userId,

                Operation =
                    operation,

                RequestHash =
                    requestHash,

                Status =
                    "Completed",

                ResponseStatusCode =
                    responseStatusCode,

                ResponseBody =
                    responseBody,

                CreatedAtUtc =
                    DateTime.UtcNow,

                CompletedAtUtc =
                    DateTime.UtcNow,

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddHours(1)
            });

        await context.SaveChangesAsync();
    }

    public async Task<int> SeedNotificationAsync(
        int userId,
        string title,
        bool isRead = false)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var notification =
            new Notification
            {
                UserId =
                    userId,

                Title =
                    title,

                Message =
                    "Integration test notification.",

                IsRead =
                    isRead,

                SentAtUtc =
                    DateTime.UtcNow,

                CreatedAtUtc =
                    DateTime.UtcNow,

                ActionType =
                    MindBloom.Domain.Enums
                        .NotificationActionType.None
            };

        context.Notifications.Add(
            notification);

        await context.SaveChangesAsync();

        return notification.Id;
    }

    private static string CreateIdempotencyRequestHash(
        string operation,
        object actionArguments)
    {
        var values =
            actionArguments
                .GetType()
                .GetProperties()
                .ToDictionary(
                    property =>
                        ToCamelCaseForIdempotency(
                            property.Name),
                    property =>
                        property.GetValue(
                            actionArguments));

        var normalized =
            new SortedDictionary<
                string,
                object?>(
                values,
                StringComparer.Ordinal);

        var options =
            new JsonSerializerOptions(
                JsonSerializerDefaults.Web)
            {
                WriteIndented =
                    false
            };

        var serialized =
            JsonSerializer.Serialize(
                normalized,
                options);

        var input =
            operation
            + "\n"
            + serialized;

        var bytes =
            System.Security.Cryptography
                .SHA256.HashData(
                    Encoding.UTF8
                        .GetBytes(input));

        return Convert.ToHexString(
            bytes);
    }

    private static string ToCamelCaseForIdempotency(
        string value)
    {
        if (string.IsNullOrEmpty(value) ||
            char.IsLower(value[0]))
        {
            return value;
        }

        return char.ToLowerInvariant(
                   value[0])
               + value[1..];
    }

    public TestNotificationPublisher
    GetTestNotificationPublisher()
    {
        return Services
            .GetRequiredService<
                TestNotificationPublisher>();
    }

    public async Task EnsureRoleExistsAsync(
        string role)
    {
        using var scope =
            Services.CreateScope();

        var roleManager =
            scope.ServiceProvider
                .GetRequiredService<
                    RoleManager<
                        IdentityRole<int>>>();

        if (await roleManager
                .RoleExistsAsync(role))
        {
            return;
        }

        var result =
            await roleManager.CreateAsync(
                new IdentityRole<int>
                {
                    Name =
                        role
                });

        if (!result.Succeeded)
        {
            throw new InvalidOperationException(
                string.Join(
                    "; ",
                    result.Errors
                        .Select(x =>
                            x.Description)));
        }
    }
}