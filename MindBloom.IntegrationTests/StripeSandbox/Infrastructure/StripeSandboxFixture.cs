using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;
using Testcontainers.MsSql;

namespace MindBloom.IntegrationTests
    .StripeSandbox.Infrastructure;

public sealed class StripeSandboxFixture
    : IAsyncLifetime
{
    private readonly MsSqlContainer
        _sqlContainer =
            new MsSqlBuilder()
                .WithPassword(
                    "MindBloom_Stripe_123!")
                .Build();

    private readonly string
        _databaseName =
            $"MindBloomStripeSandbox_"
            + $"{Guid.NewGuid():N}";

    private string
        _connectionString =
            string.Empty;

    public string StripeSecretKey
    {
        get;
        private set;
    } = string.Empty;

    public string WebhookSecret
    {
        get;
        private set;
    } = string.Empty;

    public IStripeClient StripeClient
    {
        get;
        private set;
    } = null!;

    public async Task InitializeAsync()
    {
        StripeSecretKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SANDBOX_SECRET_KEY")
            ?? string.Empty;

        if (string.IsNullOrWhiteSpace(
                StripeSecretKey))
        {
            throw new InvalidOperationException(
                "STRIPE_SANDBOX_SECRET_KEY is not configured. "
                + "Set it to a Stripe TEST secret key before running "
                + "Stripe sandbox integration tests.");
        }

        if (!StripeSecretKey.StartsWith(
                "sk_test_",
                StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "Stripe sandbox tests require a test-mode "
                + "secret key beginning with 'sk_test_'.");
        }

        /*
         * Ovo nije pravi Stripe endpoint webhook secret.
         *
         * Koristimo zaseban test signing secret za
         * automatizovano testiranje potpisa endpointa.
         */
        WebhookSecret =
            "whsec_mindbloom_"
            + Guid.NewGuid()
                .ToString("N");

        StripeClient =
            new StripeClient(
                StripeSecretKey);

        await _sqlContainer
            .StartAsync();

        var masterConnectionString =
            _sqlContainer
                .GetConnectionString();

        var builder =
            new SqlConnectionStringBuilder(
                masterConnectionString)
            {
                InitialCatalog =
                    "master"
            };

        await using (
            var masterConnection =
                new SqlConnection(
                    builder.ConnectionString))
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

        builder.InitialCatalog =
            _databaseName;

        _connectionString =
            builder.ConnectionString;

        await using var context =
            CreateDbContext();

        await context.Database
            .EnsureCreatedAsync();
    }

    public ApplicationDbContext
        CreateDbContext()
    {
        if (string.IsNullOrWhiteSpace(
                _connectionString))
        {
            throw new InvalidOperationException(
                "Stripe sandbox fixture has not been initialized.");
        }

        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseSqlServer(
                    _connectionString)
                .Options;

        return new ApplicationDbContext(
            options);
    }

    public PaymentIntentService
        CreatePaymentIntentService()
    {
        return new PaymentIntentService(
            StripeClient);
    }

    public RefundService
        CreateRefundService()
    {
        return new RefundService(
            StripeClient);
    }

    public EventService
        CreateEventService()
    {
        return new EventService(
            StripeClient);
    }

    public async Task<PaymentIntent>
        CreateAndConfirmSuccessfulPaymentAsync(
            long amount = 5000,
            string currency = "usd")
    {
        var paymentIntentService =
            CreatePaymentIntentService();

        var paymentIntent =
            await paymentIntentService
                .CreateAsync(
                    new PaymentIntentCreateOptions
                    {
                        Amount =
                            amount,

                        Currency =
                            currency,

                        PaymentMethodTypes =
                            new List<string>
                            {
                                "card"
                            },

                        PaymentMethod =
                            "pm_card_visa",

                        Confirm =
                            true,

                        Metadata =
                            new Dictionary<
                                string,
                                string>
                            {
                                ["testSuite"] =
                                    "MindBloom",

                                ["testType"] =
                                    "StripeSandbox"
                            }
                    });

        return paymentIntent;
    }

    public async Task<PaymentIntent>
        CreatePaymentIntentAsync(
            long amount = 5000,
            string currency = "usd")
    {
        var service =
            CreatePaymentIntentService();

        return await service
            .CreateAsync(
                new PaymentIntentCreateOptions
                {
                    Amount =
                        amount,

                    Currency =
                        currency,

                    PaymentMethodTypes =
                        new List<string>
                        {
                            "card"
                        },

                    Metadata =
                        new Dictionary<
                            string,
                            string>
                        {
                            ["testSuite"] =
                                "MindBloom",

                            ["testType"] =
                                "StripeSandbox"
                        }
                });
    }

    public async Task DisposeAsync()
    {
        try
        {
            if (!string.IsNullOrWhiteSpace(
                    _connectionString))
            {
                var masterBuilder =
                    new SqlConnectionStringBuilder(
                        _sqlContainer
                            .GetConnectionString())
                    {
                        InitialCatalog =
                            "master"
                    };

                await using var connection =
                    new SqlConnection(
                        masterBuilder
                            .ConnectionString);

                await connection
                    .OpenAsync();

                await using var command =
                    connection
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
            await _sqlContainer
                .DisposeAsync();
        }
    }
}