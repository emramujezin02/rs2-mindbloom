using System.Net;
using System.Net.Http.Headers;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;
using Xunit;

namespace MindBloom.SecurityTests.Authorization;

public sealed class TherapistClientAccessSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public TherapistClientAccessSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        Therapist_CannotAccessUnrelatedClientsMoodHistory()
    {
        const int therapistUserId =
            97001;

        const int clientUserId =
            97002;

        await _factory
            .SeedActiveUserAsync(
                therapistUserId,
                RoleConstants.Therapist);

        await _factory
            .SeedActiveUserAsync(
                clientUserId,
                RoleConstants.Client);

        await _factory
            .SeedTherapistProfileAsync(
                therapistUserId);

        var unrelatedClientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        /*
         * Namjerno NE kreiramo Appointment
         * niti ClientMembership između njih.
         *
         * Dakle terapeut nema profesionalni
         * odnos sa ovim clientom.
         */

        var therapistToken =
            TestJwtTokenFactory
                .CreateValidToken(
                    therapistUserId,
                    RoleConstants.Therapist);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                therapistToken);

        var response =
            await client.GetAsync(
                $"/api/JournalEntries/clients/{unrelatedClientId}/history"
                + "?pageNumber=1&pageSize=10");

        Assert.Equal(
            HttpStatusCode.NotFound,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Therapist_CannotAccessUnrelatedClientsMoodAnalytics()
    {
        const int therapistUserId =
            97003;

        const int clientUserId =
            97004;

        await _factory
            .SeedActiveUserAsync(
                therapistUserId,
                RoleConstants.Therapist);

        await _factory
            .SeedActiveUserAsync(
                clientUserId,
                RoleConstants.Client);

        await _factory
            .SeedTherapistProfileAsync(
                therapistUserId);

        var unrelatedClientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        var therapistToken =
            TestJwtTokenFactory
                .CreateValidToken(
                    therapistUserId,
                    RoleConstants.Therapist);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                therapistToken);

        var response =
            await client.GetAsync(
                $"/api/JournalEntries/clients/{unrelatedClientId}/analytics"
                + "?days=30");

        Assert.Equal(
            HttpStatusCode.NotFound,
            response.StatusCode);
    }
}