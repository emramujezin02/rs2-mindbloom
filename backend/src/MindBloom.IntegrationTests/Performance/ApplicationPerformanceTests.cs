using System.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.AdminReports.DTOs;
using MindBloom.Application.Features.AdminReports.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Application.Recommendations.Services;
using MindBloom.Domain.Enums;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Performance;

public sealed class ApplicationPerformanceTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    /*
     * Performance cilj definisan za MindBloom:
     * p95 response time < 500 ms.
     */
    private const double
        MaximumP95Milliseconds =
            500;

    private const int
        WarmupIterations =
            3;

    private const int
        MeasurementIterations =
            20;

    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public ApplicationPerformanceTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        Recommendation_P95_IsBelowPerformanceTarget()
    {
        const int clientUserId =
            174001;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "performance-recommendation-client@mindbloom.test",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                clientUserId);

        /*
         * Realističniji skup terapeuta kako ne bismo
         * mjerili potpuno praznu recommendation bazu.
         */
        for (var index = 0;
             index < 20;
             index++)
        {
            var therapistUserId =
                174100 + index;

            await _factory.SeedActiveUserAsync(
                therapistUserId,
                RoleConstants.Therapist,
                $"performance-recommendation-{index}@mindbloom.test",
                "Password123!");

            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);
        }

        var request =
            new TherapistRecommendationRequestDto
            {
                Take =
                    10,

                MaximumPricePerSession =
                    100m,

                MinimumExperienceYears =
                    1,

                PreferredDays =
                    [
                        DayOfWeek.Monday,
                        DayOfWeek.Wednesday
                    ]
            };

        async Task ExecuteAsync()
        {
            using var scope =
                _factory.Services
                    .CreateScope();

            var service =
                scope.ServiceProvider
                    .GetRequiredService<
                        IRecommendationService>();

            var result =
                await service
                    .GetRecommendationsAsync(
                        clientUserId,
                        request,
                        CancellationToken.None);

            Assert.NotNull(
                result);
        }

        var p95 =
            await MeasureP95Async(
                ExecuteAsync);

        AssertPerformanceTarget(
            "Recommendation",
            p95);
    }

    [Fact]
    public async Task
        Login_P95_IsBelowPerformanceTarget()
    {
        const int userId =
            174201;

        const string email =
            "performance-login@mindbloom.test";

        const string password =
            "Password123!";

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            email,
            password);

        var request =
            new LoginRequestDto
            {
                Email =
                    email,

                Password =
                    password,

                RememberMe =
                    false
            };

        /*
         * Login mjerimo direktno kroz IAuthService.
         *
         * API login ima namjerni rate limiting.
         * Višestruki performance pozivi prema HTTP
         * endpointu bi zato mogli dati 429 i mjerili
         * bismo rate limiter umjesto login logike.
         */
        async Task ExecuteAsync()
        {
            using var scope =
                _factory.Services
                    .CreateScope();

            var service =
                scope.ServiceProvider
                    .GetRequiredService<
                        IAuthService>();

            var result =
                await service
                    .LoginAsync(
                        request);

            Assert.NotNull(
                result);
        }

        var p95 =
            await MeasureP95Async(
                ExecuteAsync);

        AssertPerformanceTarget(
            "Login",
            p95);
    }

    [Fact]
    public async Task
        TherapistSearch_P95_IsBelowPerformanceTarget()
    {
        for (var index = 0;
             index < 25;
             index++)
        {
            var therapistUserId =
                174300 + index;

            await _factory.SeedActiveUserAsync(
                therapistUserId,
                RoleConstants.Therapist,
                $"performance-search-{index}@mindbloom.test",
                "Password123!");

            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);
        }

        var request =
            new SearchTherapistsDto
            {
                SearchText =
                    "Integration",

                SessionMode =
                    "online",

                MinPrice =
                    0m,

                MaxPrice =
                    100m,

                SortBy =
                    "experience",

                PageNumber =
                    1,

                PageSize =
                    10
            };

        async Task ExecuteAsync()
        {
            using var scope =
                _factory.Services
                    .CreateScope();

            var service =
                scope.ServiceProvider
                    .GetRequiredService<
                        ITherapistService>();

            var result =
                await service
                    .SearchAsync(
                        request);

            Assert.NotNull(
                result);

            Assert.True(
                result.PageNumber >=
                1);
        }

        var p95 =
            await MeasureP95Async(
                ExecuteAsync);

        AssertPerformanceTarget(
            "Search",
            p95);
    }

    [Fact]
    public async Task
        Dashboard_P95_IsBelowPerformanceTarget()
    {
        /*
         * Dashboard treba imati barem nešto podataka
         * kako ne bismo mjerili samo prazne agregacije.
         */
        const int clientUserId =
            174401;

        const int therapistUserId =
            174402;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "performance-dashboard-client@mindbloom.test",
            "Password123!");

        var clientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "performance-dashboard-therapist@mindbloom.test",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        for (var index = 0;
             index < 10;
             index++)
        {
            await _factory.SeedAppointmentAsync(
                clientId,
                therapistId,
                index % 2 == 0
                    ? AppointmentStatus.Completed
                    : AppointmentStatus.Accepted,
                isPaid:
                    index % 2 == 0);
        }

        var query =
            new AdminDashboardReportQueryDto
            {
                FromUtc =
                    DateTime.UtcNow
                        .AddMonths(-6),

                ToUtc =
                    DateTime.UtcNow
            };

        async Task ExecuteAsync()
        {
            using var scope =
                _factory.Services
                    .CreateScope();

            var service =
                scope.ServiceProvider
                    .GetRequiredService<
                        IAdminReportService>();

            var result =
                await service
                    .GetDashboardReportAsync(
                        query,
                        CancellationToken.None);

            Assert.NotNull(
                result);
        }

        var p95 =
            await MeasureP95Async(
                ExecuteAsync);

        AssertPerformanceTarget(
            "Dashboard",
            p95);
    }

    [Fact]
    public async Task
        Chat_P95_IsBelowPerformanceTarget()
    {
        const int clientUserId =
            174501;

        const int therapistUserId =
            174502;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "performance-chat-client@mindbloom.test",
            "Password123!");

        var clientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "performance-chat-therapist@mindbloom.test",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var appointmentId =
            await _factory
                .SeedAppointmentAsync(
                    clientId,
                    therapistId,
                    AppointmentStatus.Accepted);

        using var client =
            _factory
                .CreateAuthenticatedClient(
                    clientUserId,
                    RoleConstants.Client,
                    "performance-chat-client@mindbloom.test");

        /*
         * Prvi poziv kreira conversation.
         * Nije dio mjerenja.
         */
        var setupResponse =
            await client.PostAsync(
                "/api/Chat/appointments/"
                + $"{appointmentId}"
                + "/conversation",
                null);

        Assert.True(
            setupResponse
                .IsSuccessStatusCode);

        /*
         * Nakon kreiranja conversation-a mjerimo
         * stabilan chat access workflow.
         *
         * Isti endpoint tada pronalazi postojeći
         * conversation umjesto kreiranja novog.
         */
        async Task ExecuteAsync()
        {
            var response =
                await client.PostAsync(
                    "/api/Chat/appointments/"
                    + $"{appointmentId}"
                    + "/conversation",
                    null);

            Assert.True(
                response.IsSuccessStatusCode,
                $"Chat returned "
                + $"{(int)response.StatusCode} "
                + $"{response.StatusCode}.");

            response.Dispose();
        }

        var p95 =
            await MeasureP95Async(
                ExecuteAsync);

        AssertPerformanceTarget(
            "Chat",
            p95);
    }

    private static async Task<double>
        MeasureP95Async(
            Func<Task> operation)
    {
        ArgumentNullException.ThrowIfNull(
            operation);

        /*
         * Warm-up uklanja većinu JIT/DI inicijalnog
         * troška iz stvarnog performance uzorka.
         */
        for (var index = 0;
             index < WarmupIterations;
             index++)
        {
            await operation();
        }

        var measurements =
            new List<double>(
                MeasurementIterations);

        for (var index = 0;
             index <
             MeasurementIterations;
             index++)
        {
            var stopwatch =
                Stopwatch.StartNew();

            await operation();

            stopwatch.Stop();

            measurements.Add(
                stopwatch.Elapsed
                    .TotalMilliseconds);
        }

        measurements.Sort();

        /*
         * Nearest-rank p95:
         * ceil(0.95 * N) - 1
         */
        var percentileIndex =
            (int)Math.Ceiling(
                measurements.Count *
                0.95)
            - 1;

        percentileIndex =
            Math.Clamp(
                percentileIndex,
                0,
                measurements.Count - 1);

        return measurements[
            percentileIndex];
    }

    private static void
        AssertPerformanceTarget(
            string operation,
            double p95Milliseconds)
    {
        Assert.True(
            p95Milliseconds <
            MaximumP95Milliseconds,

            $"{operation} performance target failed. "
            + $"Measured p95: "
            + $"{p95Milliseconds:F2} ms. "
            + $"Required p95: "
            + $"< {MaximumP95Milliseconds:F0} ms.");
    }
}