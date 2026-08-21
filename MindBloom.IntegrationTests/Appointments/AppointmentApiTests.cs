using System.Net;
using System.Net.Http.Json;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Appointments;

public sealed class AppointmentApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public AppointmentApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        Mine_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Appointments/mine");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Mine_WithTherapistRole_ReturnsForbidden()
    {
        const int userId = 81001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Therapist,
            "appointment-therapist@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Therapist);

        var response =
            await client.GetAsync(
                "/api/Appointments/mine");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Mine_ReturnsOnlyAuthenticatedClientsAppointments()
    {
        const int firstUserId = 81002;
        const int secondUserId = 81003;
        const int therapistUserId = 81004;

        await _factory.SeedActiveUserAsync(
            firstUserId,
            RoleConstants.Client,
            "appointment-client-one@test.local",
            "Password123!");

        var firstClientId =
            await _factory
                .SeedClientProfileAsync(
                    firstUserId);

        await _factory.SeedActiveUserAsync(
            secondUserId,
            RoleConstants.Client,
            "appointment-client-two@test.local",
            "Password123!");

        var secondClientId =
            await _factory
                .SeedClientProfileAsync(
                    secondUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "appointment-therapist-two@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var firstAppointmentId =
            await _factory.SeedAppointmentAsync(
                firstClientId,
                therapistId,
                AppointmentStatus.Accepted);

        await _factory.SeedAppointmentAsync(
            secondClientId,
            therapistId,
            AppointmentStatus.Accepted);

        using var client =
            _factory.CreateAuthenticatedClient(
                firstUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Appointments/mine");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var body =
            await response.Content
                .ReadFromJsonAsync<
                    List<AppointmentResponseDto>>();

        Assert.NotNull(body);

        var appointment =
            Assert.Single(body!);

        Assert.Equal(
            firstAppointmentId,
            appointment.Id);

        Assert.Equal(
            firstClientId,
            appointment.ClientId);
    }

    [Fact]
    public async Task
        GetDetails_WhenAppointmentBelongsToAnotherClient_ReturnsNotFound()
    {
        const int ownerUserId = 81005;
        const int otherUserId = 81006;
        const int therapistUserId = 81007;

        await _factory.SeedActiveUserAsync(
            ownerUserId,
            RoleConstants.Client,
            "appointment-owner@test.local",
            "Password123!");

        var ownerClientId =
            await _factory
                .SeedClientProfileAsync(
                    ownerUserId);

        await _factory.SeedActiveUserAsync(
            otherUserId,
            RoleConstants.Client,
            "appointment-other@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                otherUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "appointment-owner-therapist@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var appointmentId =
            await _factory.SeedAppointmentAsync(
                ownerClientId,
                therapistId,
                AppointmentStatus.Accepted);

        using var client =
            _factory.CreateAuthenticatedClient(
                otherUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                $"/api/Appointments/{appointmentId}");

        Assert.Equal(
            HttpStatusCode.NotFound,
            response.StatusCode);
    }
}