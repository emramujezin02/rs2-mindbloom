using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using System.Security.Cryptography;
using System.Text;
using MindBloom.Application.Common.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Configuration;

namespace MindBloom.SecurityTests.Infrastructure;

public sealed class MindBloomWebApplicationFactory
    : WebApplicationFactory<Program>
{
    public const string TestJwtSecret =
        "MindBloom.SecurityTests.JWT.Secret.2026.Only.For.Automated.Tests!";

    public const string TestJwtIssuer =
        "MindBloom.SecurityTests";

    public const string TestJwtAudience =
        "MindBloom.SecurityTests.Client";

    public const string TestStripeWebhookSecret =
        "whsec_mindbloom_security_tests_only";

    private readonly string _databaseName =
        $"MindBloomSecurityTests-{Guid.NewGuid():N}";

    public MindBloomWebApplicationFactory()
    {
        ConfigureTestEnvironmentVariables();
    }

    protected override void ConfigureWebHost(
        IWebHostBuilder builder)
    {
        builder.UseEnvironment(
            "Testing");

        builder.ConfigureAppConfiguration(
    (_, configuration) =>
    {
        var testConfiguration =
            new Dictionary<string, string?>
            {
                ["RABBITMQ_HOST"] =
                    "localhost",

                ["RABBITMQ_PORT"] =
                    "5672",

                ["RABBITMQ_USERNAME"] =
                    "security-tests",

                ["RABBITMQ_USER"] =
                    "security-tests",

                ["RABBITMQ_PASSWORD"] =
                    "security-tests-password",

                ["RABBITMQ_VIRTUAL_HOST"] =
                    "/",

                ["RABBITMQ_CLIENT_NAME"] =
                    "mindbloom-security-tests-api",

                ["RABBITMQ_WORKER_CLIENT_NAME"] =
                    "mindbloom-security-tests-worker",

                ["RABBITMQ_NOTIFICATION_EXCHANGE"] =
                    "mindbloom.security-tests.notifications",

                ["RABBITMQ_EXCHANGE"] =
                    "mindbloom.security-tests.notifications",

                ["RABBITMQ_EMAIL_QUEUE"] =
                    "mindbloom.security-tests.email",

                ["RABBITMQ_EMAIL_ROUTING_KEY"] =
                    "notification.email",

                ["RABBITMQ_INTEGRATION_EVENT_QUEUE"] =
                    "mindbloom.security-tests.integration",

                ["RABBITMQ_RETRY_EXCHANGE"] =
                    "mindbloom.security-tests.retry",

                ["RABBITMQ_DEAD_LETTER_EXCHANGE"] =
                    "mindbloom.security-tests.dead-letter",

                ["RABBITMQ_EMAIL_DEAD_LETTER_QUEUE"] =
                    "mindbloom.security-tests.email.dlq",

                ["RABBITMQ_EMAIL_DEAD_LETTER_ROUTING_KEY"] =
                    "notification.email.dead",

                ["RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_QUEUE"] =
                    "mindbloom.security-tests.integration.dlq",

                ["RABBITMQ_INTEGRATION_EVENT_DEAD_LETTER_ROUTING_KEY"] =
                    "notification.integration.dead",

                ["RABBITMQ_PREFETCH_COUNT"] =
                    "1",

                ["RABBITMQ_MAXIMUM_RETRY_COUNT"] =
                    "4",

                ["RABBITMQ_AUTOMATIC_RECOVERY"] =
                    "false",

                ["RABBITMQ_RECOVERY_INTERVAL_SECONDS"] =
                    "1",

                ["RABBITMQ_HEARTBEAT_SECONDS"] =
                    "30",

                ["RABBITMQ_CONNECTION_RETRY_COUNT"] =
                    "1",

                ["RABBITMQ_CONNECTION_RETRY_DELAY_SECONDS"] =
                    "1"
            };

        configuration.AddInMemoryCollection(
            testConfiguration);
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
                services.RemoveAll<
    IJwtTokenService>();

                services.AddScoped<
                    IJwtTokenService,
                    TestJwtTokenService>();

                var hostedServicesToRemove =
                    services
                        .Where(descriptor =>
                            descriptor.ServiceType ==
                                typeof(IHostedService)
                            &&
                            descriptor
                                .ImplementationType?
                                .Name ==
                            "AppointmentReminderService")
                        .ToList();

                foreach (var descriptor
                         in hostedServicesToRemove)
                {
                    services.Remove(
                        descriptor);
                }
            });
    }



    private static void
        ConfigureTestEnvironmentVariables()
    {
        Environment.SetEnvironmentVariable(
            "ASPNETCORE_ENVIRONMENT",
            "Testing");

        Environment.SetEnvironmentVariable(
            "DOTNET_ENVIRONMENT",
            "Testing");

        /*
         * AddInfrastructure trenutno zahtijeva
         * DB_CONNECTION tokom registracije servisa.
         *
         * Ova vrijednost se nikada ne koristi za
         * povezivanje jer je DbContext poslije
         * zamijenjen InMemory providerom.
         */
        Environment.SetEnvironmentVariable(
            "DB_CONNECTION",
            "Server=localhost;"
            + "Database=MindBloomSecurityTests;"
            + "User Id=test;"
            + "Password=TestOnlyPassword123!;"
            + "TrustServerCertificate=True;"
            + "Encrypt=False;");

        Environment.SetEnvironmentVariable(
            "JWT_SECRET",
            TestJwtSecret);

        Environment.SetEnvironmentVariable(
            "JWT_ISSUER",
            TestJwtIssuer);

        Environment.SetEnvironmentVariable(
            "JWT_AUDIENCE",
            TestJwtAudience);

        Environment.SetEnvironmentVariable(
            "JWT_EXPIRATION_MINUTES",
            "15");

        Environment.SetEnvironmentVariable(
            "STRIPE_SECRET_KEY",
            "sk_test_mindbloom_security_tests_only");

        Environment.SetEnvironmentVariable(
            "STRIPE_WEBHOOK_SECRET",
            TestStripeWebhookSecret);

        /*
         * Testne vrijednosti za messaging konfiguraciju.
         * Security testovi ne šalju stvarne RabbitMQ
         * poruke niti emailove.
         */
        Environment.SetEnvironmentVariable(
            "RABBITMQ_HOST",
            "localhost");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_PORT",
            "5672");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_USERNAME",
            "security-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_USER",
            "security-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_PASSWORD",
            "security-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_VIRTUAL_HOST",
            "/");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_CLIENT_NAME",
            "mindbloom-security-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_NOTIFICATION_EXCHANGE",
            "mindbloom.security-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EXCHANGE",
            "mindbloom.security-tests");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EMAIL_QUEUE",
            "mindbloom.security-tests.email");

        Environment.SetEnvironmentVariable(
            "RABBITMQ_EMAIL_ROUTING_KEY",
            "mindbloom.security-tests.email");

        Environment.SetEnvironmentVariable(
            "EMAIL_USERNAME",
            "security-tests@mindbloom.test");

        Environment.SetEnvironmentVariable(
            "EMAIL_PASSWORD",
            "security-tests-only");
    }

    public async Task SetUserSecurityStateAsync(
    int userId,
    bool isActive,
    bool isBlocked)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var user =
            await context.Users
                .FirstOrDefaultAsync(
                    x =>
                        x.Id == userId);

        if (user == null)
        {
            throw new InvalidOperationException(
                $"Security test user {userId} was not found.");
        }

        user.IsActive =
            isActive;

        user.IsBlocked =
            isBlocked;

        await context.SaveChangesAsync();
    }

    public async Task SeedActiveUserAsync(
     int userId,
     string role,
     string? email = null,
     string? password = null)
    {
        using var scope =
            Services.CreateScope();

        var userManager =
            scope.ServiceProvider
                .GetRequiredService<
                    UserManager<ApplicationUser>>();

        var existingUser =
            await userManager
                .FindByIdAsync(
                    userId.ToString());

        if (existingUser != null)
        {
            return;
        }

        var resolvedEmail =
            string.IsNullOrWhiteSpace(email)
                ? $"security-test-{userId}@mindbloom.test"
                : email.Trim();

        var username =
            $"security-test-{userId}";

        var user =
            new ApplicationUser
            {
                Id =
                    userId,

                FirstName =
                    "Security",

                LastName =
                    "Test",

                Email =
                    resolvedEmail,

                UserName =
                    username,

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

                LockoutEnd =
                    null,

                CreatedAtUtc =
                    DateTime.UtcNow,

                DateOfBirth =
                    new DateTime(
                        1995,
                        1,
                        1),

                Gender =
                    "Other"
            };

        IdentityResult createResult;

        if (!string.IsNullOrWhiteSpace(
                password))
        {
            createResult =
                await userManager.CreateAsync(
                    user,
                    password);
        }
        else
        {
            createResult =
                await userManager.CreateAsync(
                    user);
        }

        if (!createResult.Succeeded)
        {
            throw new InvalidOperationException(
                "Security test user could not be created: "
                + string.Join(
                    "; ",
                    createResult.Errors.Select(
                        error =>
                            error.Description)));
        }

        var normalizedRole =
    role.Trim();

        if (!string.IsNullOrWhiteSpace(
                normalizedRole))
        {
            var roleManager =
                scope.ServiceProvider
                    .GetRequiredService<
                        RoleManager<IdentityRole<int>>>();

            var roleExists =
                await roleManager
                    .RoleExistsAsync(
                        normalizedRole);

            if (!roleExists)
            {
                var createRoleResult =
                    await roleManager
                        .CreateAsync(
                            new IdentityRole<int>
                            {
                                Name =
                                    normalizedRole
                            });

                if (!createRoleResult.Succeeded)
                {
                    throw new InvalidOperationException(
                        "Security test role could not be created: "
                        + string.Join(
                            "; ",
                            createRoleResult.Errors.Select(
                                error =>
                                    error.Description)));
                }
            }

            var userHasRole =
                await userManager
                    .IsInRoleAsync(
                        user,
                        normalizedRole);

            if (!userHasRole)
            {
                var addRoleResult =
                    await userManager
                        .AddToRoleAsync(
                            user,
                            normalizedRole);

                if (!addRoleResult.Succeeded)
                {
                    throw new InvalidOperationException(
                        "Security test role could not be assigned: "
                        + string.Join(
                            "; ",
                            addRoleResult.Errors.Select(
                                error =>
                                    error.Description)));
                }
            }
        }
    }

    public async Task<string>
    CreatePasswordResetTokenAsync(
        int userId)
    {
        using var scope =
            Services.CreateScope();

        var userManager =
            scope.ServiceProvider
                .GetRequiredService<
                    UserManager<ApplicationUser>>();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var user =
            await userManager
                .FindByIdAsync(
                    userId.ToString());

        if (user == null)
        {
            throw new InvalidOperationException(
                "Security test user was not found.");
        }

        var identityToken =
            await userManager
                .GeneratePasswordResetTokenAsync(
                    user);

        var encodedToken =
            WebEncoders.Base64UrlEncode(
                Encoding.UTF8.GetBytes(
                    identityToken));

        var tokenBytes =
            Encoding.UTF8.GetBytes(
                encodedToken.Trim());

        var tokenHash =
            Convert.ToHexString(
                SHA256.HashData(
                    tokenBytes));

        context.PasswordResetCodes.Add(
            new PasswordResetCode
            {
                Email =
                    user.Email!
                        .Trim()
                        .ToLowerInvariant(),

                TokenHash =
                    tokenHash,

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddMinutes(15),

                IsUsed =
                    false,

                UsedAtUtc =
                    null
            });

        await context.SaveChangesAsync();

        return encodedToken;
    }

    public async Task SeedRefreshTokenAsync(
    int userId,
    string rawRefreshToken,
    string sessionId,
    bool isRevoked = false,
    DateTime? expiresAtUtc = null)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        if (string.IsNullOrWhiteSpace(
                rawRefreshToken))
        {
            throw new ArgumentException(
                "Refresh token is required.",
                nameof(rawRefreshToken));
        }

        if (string.IsNullOrWhiteSpace(
                sessionId))
        {
            throw new ArgumentException(
                "Session identifier is required.",
                nameof(sessionId));
        }

        var tokenHash =
            Convert.ToHexString(
                SHA256.HashData(
                    Encoding.UTF8.GetBytes(
                        rawRefreshToken.Trim())));

        var refreshToken =
            new RefreshToken
            {
                UserId =
                    userId,

                TokenHash =
                    tokenHash,

                IssuedAtUtc =
                    DateTime.UtcNow
                        .AddMinutes(-5),

                ExpiresAtUtc =
                    expiresAtUtc ??
                    DateTime.UtcNow
                        .AddDays(1),

                RevokedAtUtc =
                    isRevoked
                        ? DateTime.UtcNow
                            .AddMinutes(-1)
                        : null,

                ReplacedByTokenHash =
                    null,

                SessionId =
                    sessionId
            };

        context.RefreshTokens.Add(
            refreshToken);

        await context.SaveChangesAsync();
    }

    public async Task<int> SeedClientProfileAsync(
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
                    x => x.UserId == userId);

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
                    true,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.Clients.Add(client);

        await context.SaveChangesAsync();

        return client.Id;
    }

    public async Task<int> SeedTherapistProfileAsync(
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
                    x => x.UserId == userId);

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
                    "Security test therapist.",

                Specialization =
                    "Security testing",

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
                    "Security test address",

                Education =
                    "Security test education",

                OffersOnline =
                    true,

                OffersInPerson =
                    false,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist.Id;
    }

    public async Task<int>
        SeedPrivateJournalEntryAsync(
            int clientId)
    {
        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var entry =
            new PrivateJournalEntry
            {
                ClientId =
                    clientId,

                Title =
                    "Private security test",

                Content =
                    "This content must not be visible to another user.",

                EntryDateUtc =
                    DateTime.UtcNow,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.PrivateJournalEntries.Add(
            entry);

        await context.SaveChangesAsync();

        return entry.Id;
    }


}