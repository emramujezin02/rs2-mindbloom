using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Appointments;

public sealed class AppointmentRejectionAuthorizationApiTests
{
    [Theory]
    [InlineData("Client", HttpStatusCode.Forbidden)]
    [InlineData("Therapist", HttpStatusCode.NotFound)]
    [InlineData("Anonymous", HttpStatusCode.Unauthorized)]
    public async Task OnlyOwningTherapistCanReject(string role, HttpStatusCode expected)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        await factory.SeedActiveUserAsync(74101, RoleConstants.Client, "rejection-client@test.local", "Password123!");
        await factory.SeedActiveUserAsync(74102, RoleConstants.Therapist, "rejection-owner@test.local", "Password123!");
        await factory.SeedActiveUserAsync(74103, RoleConstants.Therapist, "rejection-other@test.local", "Password123!");
        var client = await factory.SeedClientProfileAsync(74101);
        var therapist = await factory.SeedTherapistProfileAsync(74102);
        await factory.SeedTherapistProfileAsync(74103);
        var id = await factory.SeedAppointmentAsync(client, therapist, AppointmentStatus.Pending);
        using var http = role == "Anonymous" ? factory.CreateClient()
            : factory.CreateAuthenticatedClient(role == "Client" ? 74101 : 74103, role);
        using var response = await http.PutAsJsonAsync("/api/Appointments/status", new UpdateAppointmentStatusDto
            { AppointmentId = id, Status = AppointmentStatus.Rejected, Reason = "A scheduling conflict" });
        Assert.Equal(expected, response.StatusCode);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(AppointmentStatus.Pending, (await db.Appointments.FindAsync(id))!.Status);
        Assert.Empty(await db.AppointmentStatusAudits.ToListAsync());
        Assert.Empty(await db.OutboxMessages.ToListAsync());
    }
}
