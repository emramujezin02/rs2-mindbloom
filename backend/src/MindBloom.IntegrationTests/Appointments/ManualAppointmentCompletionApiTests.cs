using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using MindBloom.API.Models;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Appointments;

public sealed class ManualAppointmentCompletionApiTests
{
    private static readonly DateTime Now = new(2026, 10, 29, 12, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(AppointmentStatus.Accepted, 1, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Accepted, 86400, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Accepted, 604800, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Accepted, 0, HttpStatusCode.NoContent)]
    [InlineData(AppointmentStatus.Accepted, -1, HttpStatusCode.NoContent)]
    [InlineData(AppointmentStatus.Pending, -1, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Rejected, -1, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Cancelled, -1, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Completed, -1, HttpStatusCode.Conflict)]
    public async Task StatusHttp_EnforcesTimeAndTransitionBeforeGrantingReview(
        AppointmentStatus before, int seconds, HttpStatusCode expected)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        var publisher = new TestIntegrationEventPublisher();
        using var clockFactory = factory.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<TimeProvider>(new FrozenClock());
            services.RemoveAll<IIntegrationEventPublisher>();
            services.AddSingleton<IIntegrationEventPublisher>(publisher);
        }));
        await factory.SeedActiveUserAsync(73101, RoleConstants.Client, "completion-client@test.local", "Password123!");
        await factory.SeedActiveUserAsync(73102, RoleConstants.Therapist, "completion-therapist@test.local", "Password123!");
        var clientId = await factory.SeedClientProfileAsync(73101);
        var therapistId = await factory.SeedTherapistProfileAsync(73102);
        var id = await factory.SeedAppointmentAsync(clientId, therapistId, before);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var appointment = await db.Appointments.FindAsync(id);
            appointment!.EndUtc = Now.AddSeconds(seconds);
            appointment.StartUtc = appointment.EndUtc.AddHours(-1);
            await db.SaveChangesAsync();
        }
        // Preserve the factory's authentication headers while exercising the clock-controlled host.
        using var therapist = clockFactory.CreateClient();
        using var authenticated = factory.CreateAuthenticatedClient(73102, RoleConstants.Therapist);
        foreach (var header in authenticated.DefaultRequestHeaders)
            therapist.DefaultRequestHeaders.TryAddWithoutValidation(header.Key, header.Value);
        using var response = await therapist.PutAsJsonAsync("/api/Appointments/status",
            new UpdateAppointmentStatusDto { AppointmentId = id, Status = AppointmentStatus.Completed });
        Assert.Equal(expected, response.StatusCode);
        if (expected == HttpStatusCode.Conflict)
        {
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
            var error = await response.Content.ReadFromJsonAsync<ApiErrorResponse>();
            Assert.Equal("business_rule_violation", error!.ErrorCode);
            Assert.False(string.IsNullOrWhiteSpace(error.TraceId));
            Assert.Contains(before == AppointmentStatus.Accepted ? "scheduled end time" : "not allowed", error.Detail);
        }
        using var verification = factory.Services.CreateScope();
        var verifyDb = verification.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(expected == HttpStatusCode.NoContent ? AppointmentStatus.Completed : before,
            (await verifyDb.Appointments.FindAsync(id))!.Status);
        Assert.Equal(expected == HttpStatusCode.NoContent ? 1 : 0,
            await verifyDb.AppointmentStatusAudits.CountAsync(x => x.AppointmentId == id));
        Assert.Equal(expected == HttpStatusCode.NoContent ? 1 : 0, await verifyDb.OutboxMessages.CountAsync());
        Assert.Empty(publisher.Events);

        using var client = factory.CreateAuthenticatedClient(73101, RoleConstants.Client);
        using var review = await client.PostAsJsonAsync("/api/Reviews",
            new CreateReviewDto { AppointmentId = id, Rating = 5, Comment = "Session review" });
        Assert.Equal(expected == HttpStatusCode.NoContent || before == AppointmentStatus.Completed
            ? HttpStatusCode.Created : HttpStatusCode.Conflict, review.StatusCode);
    }

    private sealed class FrozenClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(Now);
    }
}
