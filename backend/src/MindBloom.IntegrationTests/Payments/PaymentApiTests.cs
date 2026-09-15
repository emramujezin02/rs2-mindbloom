using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.Domain.Enums;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Payments;

public sealed class PaymentApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public PaymentApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        Mine_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Payments/mine");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Mine_WithTherapistRole_ReturnsForbidden()
    {
        const int userId = 82001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Therapist,
            "payment-therapist@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Therapist);

        var response =
            await client.GetAsync(
                "/api/Payments/mine");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Mine_ReturnsOnlyAuthenticatedClientsPayments()
    {
        const int clientUserId = 82002;
        const int therapistUserId = 82003;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "payment-client@test.local",
            "Password123!");

        var clientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "payment-therapist-two@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var appointmentId =
            await _factory.SeedAppointmentAsync(
                clientId,
                therapistId,
                AppointmentStatus.Accepted,
                isPaid: true);

        var paymentId =
            await _factory.SeedPaymentAsync(
                appointmentId,
                PaymentStatus.Paid);

        using var client =
            _factory.CreateAuthenticatedClient(
                clientUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Payments/mine");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            JsonValueKind.Array,
            json.ValueKind);

        Assert.True(
            json.GetArrayLength() >= 1);

        Assert.Contains(
            json.EnumerateArray(),
            item =>
                item.GetProperty("id")
                    .GetInt32() ==
                paymentId);
    }

    [Fact]
    public async Task
        Receipt_WhenPaymentBelongsToAnotherClient_ReturnsNotFound()
    {
        const int ownerUserId = 82004;
        const int otherUserId = 82005;
        const int therapistUserId = 82006;

        await _factory.SeedActiveUserAsync(
            ownerUserId,
            RoleConstants.Client,
            "payment-owner@test.local",
            "Password123!");

        var ownerClientId =
            await _factory
                .SeedClientProfileAsync(
                    ownerUserId);

        await _factory.SeedActiveUserAsync(
            otherUserId,
            RoleConstants.Client,
            "payment-other@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                otherUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "payment-owner-therapist@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var appointmentId =
            await _factory.SeedAppointmentAsync(
                ownerClientId,
                therapistId,
                AppointmentStatus.Accepted,
                isPaid: true);

        var paymentId =
            await _factory.SeedPaymentAsync(
                appointmentId,
                PaymentStatus.Paid);

        using var client =
            _factory.CreateAuthenticatedClient(
                otherUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                $"/api/Payments/{paymentId}/receipt");

        Assert.Equal(
            HttpStatusCode.NotFound,
            response.StatusCode);
    }
}