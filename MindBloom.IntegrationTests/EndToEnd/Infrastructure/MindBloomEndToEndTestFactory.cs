using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using Testcontainers.MsSql;

namespace MindBloom.IntegrationTests.EndToEnd.Infrastructure;

public sealed class MindBloomEndToEndTestFactory
    : WebApplicationFactory<Program>,
      IAsyncLifetime
{
    private readonly MsSqlContainer
        _sqlContainer =
            new MsSqlBuilder()
                .WithPassword(
                    "MindBloom_E2E_123!")
                .Build();

    private readonly string
        _databaseName =
            $"MindBloomE2E_{Guid.NewGuid():N}";

    private string
        _connectionString =
            string.Empty;

    protected override void ConfigureWebHost(
        IWebHostBuilder builder)
    {
        builder.UseEnvironment(
            "Testing");

        Environment.SetEnvironmentVariable(
            "DB_CONNECTION",
            _connectionString);

        Environment.SetEnvironmentVariable(
            "ConnectionStrings__DefaultConnection",
            _connectionString);

        Environment.SetEnvironmentVariable(
            "STRIPE_SECRET_KEY",
            "sk_test_e2e_fake");

        Environment.SetEnvironmentVariable(
            "STRIPE_WEBHOOK_SECRET",
            "whsec_e2e_fake");

        builder.ConfigureServices(
            services =>
            {
                services.RemoveAll<
                    DbContextOptions<
                        ApplicationDbContext>>();

                services.RemoveAll<
                    IDbContextOptionsConfiguration<
                        ApplicationDbContext>>();

                services.RemoveAll<
                    ApplicationDbContext>();

                services.AddDbContext<
                    ApplicationDbContext>(
                    options =>
                    {
                        options.UseSqlServer(
                            _connectionString);
                    });

                services.RemoveAll<
                    IIntegrationEventPublisher>();

                services.AddSingleton<
                    TestIntegrationEventPublisher>();

                services.AddSingleton<
                    IIntegrationEventPublisher>(
                    serviceProvider =>
                        serviceProvider
                            .GetRequiredService<
                                TestIntegrationEventPublisher>());

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
                    .AddHttpClient(
                        "Stripe")
                    .ConfigurePrimaryHttpMessageHandler(
                        () =>
                            new FakeStripeHttpMessageHandler());

                services.RemoveAll<
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

    public async Task InitializeAsync()
    {
        await _sqlContainer
            .StartAsync();

        var masterConnectionString =
            _sqlContainer
                .GetConnectionString();

        var connectionBuilder =
            new SqlConnectionStringBuilder(
                masterConnectionString)
            {
                InitialCatalog =
                    "master"
            };

        await using (
            var masterConnection =
                new SqlConnection(
                    connectionBuilder
                        .ConnectionString))
        {
            await masterConnection
                .OpenAsync();

            await using var command =
                masterConnection
                    .CreateCommand();

            command.CommandText =
                $"CREATE DATABASE [{_databaseName}]";

            await command
                .ExecuteNonQueryAsync();
        }

        connectionBuilder
            .InitialCatalog =
            _databaseName;

        _connectionString =
            connectionBuilder
                .ConnectionString;

        /*
         * ConfigureWebHost se izvršava kada
         * WebApplicationFactory prvi put napravi
         * Services.
         *
         * Zato container i connection string
         * moraju biti spremni prije ove linije.
         */
        _ = Services;

        using var scope =
            Services.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        await context.Database
            .EnsureCreatedAsync();
    }

    public new async Task DisposeAsync()
    {
        try
        {
            if (!string.IsNullOrWhiteSpace(
                    _connectionString))
            {
                /*
                 * Prvo pustimo EF scope prije
                 * brisanja test baze.
                 */
                using (var scope =
                       Services.CreateScope())
                {
                    var context =
                        scope.ServiceProvider
                            .GetRequiredService<
                                ApplicationDbContext>();

                    await context.Database
                        .CloseConnectionAsync();
                }

                var masterConnectionBuilder =
                    new SqlConnectionStringBuilder(
                        _sqlContainer
                            .GetConnectionString())
                    {
                        InitialCatalog =
                            "master"
                    };

                await using var masterConnection =
                    new SqlConnection(
                        masterConnectionBuilder
                            .ConnectionString);

                await masterConnection
                    .OpenAsync();

                await using var command =
                    masterConnection
                        .CreateCommand();

                command.CommandText =
                    $"""
                    IF DB_ID(N'{_databaseName}') IS NOT NULL
                    BEGIN
                        ALTER DATABASE [{_databaseName}]
                        SET SINGLE_USER
                        WITH ROLLBACK IMMEDIATE;

                        DROP DATABASE [{_databaseName}];
                    END
                    """;

                await command
                    .ExecuteNonQueryAsync();
            }
        }
        finally
        {
            await base.DisposeAsync();

            await _sqlContainer
                .DisposeAsync();
        }
    }

    public async Task<int> SeedActiveUserAsync(
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

        if (!await roleManager
                .RoleExistsAsync(role))
        {
            var roleResult =
                await roleManager.CreateAsync(
                    new IdentityRole<int>
                    {
                        Name =
                            role
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

        var existing =
            await userManager
                .FindByEmailAsync(
                    email);

        if (existing != null)
        {
            return existing.Id;
        }

        var unique =
            Guid.NewGuid()
                .ToString("N");

        var user =
            new ApplicationUser
            {
                FirstName =
                    "E2E",

                LastName =
                    "User",

                Email =
                    email,

                UserName =
                    $"e2e-user-{unique}",

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
            await userManager
                .CreateAsync(
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
            await userManager
                .AddToRoleAsync(
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

        return user.Id;
    }

    public HttpClient CreateBearerClient(
        string accessToken)
    {
        if (string.IsNullOrWhiteSpace(
                accessToken))
        {
            throw new ArgumentException(
                "Access token is required.",
                nameof(accessToken));
        }

        var client =
            CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new System.Net.Http.Headers
                .AuthenticationHeaderValue(
                    "Bearer",
                    accessToken);

        return client;
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
            await roleManager
                .CreateAsync(
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

    public string GetIdempotencyHeaderName()
    {
        using var scope =
            Services.CreateScope();

        var options =
            scope.ServiceProvider
                .GetRequiredService<
                    Microsoft.Extensions.Options
                        .IOptions<
                            MindBloom.API.Configuration
                                .IdempotencyOptions>>();

        return options.Value.HeaderName;
    }
}