using System.Net;
using System.Net.Http.Headers;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;
using Xunit;

namespace MindBloom.SecurityTests.Ownership;

public sealed class OwnershipSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public OwnershipSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        PrivateJournal_ClientCannotReadAnotherClientsEntry()
    {
        const int ownerUserId =
            96001;

        const int attackerUserId =
            96002;

        await _factory
            .SeedActiveUserAsync(
                ownerUserId,
                RoleConstants.Client);

        await _factory
            .SeedActiveUserAsync(
                attackerUserId,
                RoleConstants.Client);

        var ownerClientId =
            await _factory
                .SeedClientProfileAsync(
                    ownerUserId);

        await _factory
            .SeedClientProfileAsync(
                attackerUserId);

        var privateJournalEntryId =
            await _factory
                .SeedPrivateJournalEntryAsync(
                    ownerClientId);

        var attackerToken =
            TestJwtTokenFactory
                .CreateValidToken(
                    attackerUserId,
                    RoleConstants.Client);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                attackerToken);

        var response =
            await client.GetAsync(
                $"/api/PrivateJournalEntries/{privateJournalEntryId}");

        /*
         * Ne vraćamo Forbidden sa informacijom
         * da resurs postoji.
         *
         * Ownership query treba ponašati resurs
         * kao nepostojeći za drugog korisnika.
         */
        Assert.Equal(
            HttpStatusCode.NotFound,
            response.StatusCode);
    }
}