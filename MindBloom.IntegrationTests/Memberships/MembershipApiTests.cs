using System.Net;
using System.Net.Http.Json;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Memberships;

public sealed class MembershipApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public MembershipApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        Plans_IsAvailableWithoutAuthentication()
    {
        const int therapistUserId = 83001;

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "membership-public-therapist@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        await _factory
            .SeedMembershipPlanAsync();

        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                $"/api/Memberships/therapist/{therapistId}/plans");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Mine_WithTherapistRole_ReturnsForbidden()
    {
        const int userId = 83002;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Therapist,
            "membership-role@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Therapist);

        var response =
            await client.GetAsync(
                "/api/Memberships/mine");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Mine_ReturnsAuthenticatedClientsMembership()
    {
        const int clientUserId = 83003;
        const int therapistUserId = 83004;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "membership-client@test.local",
            "Password123!");

        var clientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "membership-therapist@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var membershipId =
            await _factory
                .SeedClientMembershipAsync(
                    clientId,
                    therapistId);

        using var client =
            _factory.CreateAuthenticatedClient(
                clientUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Memberships/mine");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var result =
            await response.Content
                .ReadFromJsonAsync<
                    List<MembershipResponseDto>>();

        Assert.NotNull(result);

        Assert.Contains(
            result!,
            item =>
                item.Id ==
                membershipId);
    }
}