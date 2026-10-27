using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.API.Models;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Appointments;

public sealed class AppointmentBusinessErrorApiTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task InvalidNoteOrMeetingLink_ReturnsConflict(bool updateMeetingLink)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        await factory.SeedActiveUserAsync(72101, RoleConstants.Client,
            "business-client@test.local", "Password123!");
        await factory.SeedActiveUserAsync(72102, RoleConstants.Therapist,
            "business-therapist@test.local", "Password123!");
        var clientId = await factory.SeedClientProfileAsync(72101);
        var therapistId = await factory.SeedTherapistProfileAsync(72102);
        var appointmentId = await factory.SeedAppointmentAsync(clientId, therapistId, AppointmentStatus.Accepted);
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var appointment = await context.Appointments.SingleAsync(x => x.Id == appointmentId);
            appointment.Type = AppointmentType.InPerson;
            await context.SaveChangesAsync();
        }
        using var client = factory.CreateAuthenticatedClient(72102, RoleConstants.Therapist);

        var response = updateMeetingLink
            ? await client.PutAsJsonAsync($"/api/Appointments/{appointmentId}/meeting-link",
                new UpdateMeetingLinkDto { MeetingLink = "https://example.test/session" })
            : await client.PostAsJsonAsync("/api/Appointments/notes",
                new CreateAppointmentNoteDto
                {
                    AppointmentId = appointmentId, Notes = "Session notes", ClientMood = "Good",
                    Recommendations = "Follow up"
                });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var error = await response.Content.ReadFromJsonAsync<ApiErrorResponse>();
        Assert.NotNull(error);
        Assert.Equal(409, error.StatusCode);
        Assert.Equal("business_rule_violation", error.ErrorCode);
        Assert.Equal(updateMeetingLink
            ? "Meeting link can only be added to online appointments."
            : "Notes can only be added after completed appointments.", error.Detail);
    }
}
