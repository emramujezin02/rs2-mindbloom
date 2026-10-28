using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;
using MindBloom.Application.Features.Appointments.DTOs;

namespace MindBloom.IntegrationTests.Appointments;

public sealed class AppointmentTimeZoneApiTests(MindBloomIntegrationTestFactory factory)
    : IClassFixture<MindBloomIntegrationTestFactory>
{
    [Fact]
    public async Task OccupiedApi_UsesSarajevoDateAndSerializesUtcWithZ()
    {
        const int userId = 908101;
        await factory.SeedActiveUserAsync(userId,RoleConstants.Client,"zone-client@test.local","Password123!");
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var client = new Client {UserId=userId};
        var therapist = new Therapist {User=new() {UserName="zone-therapist",FirstName="Time",LastName="Test",IsActive=true},
            Biography="Test",Specialization="Test",VerificationStatus=TherapistVerificationStatus.Approved};
        db.AddRange(client,therapist); await db.SaveChangesAsync();
        var start = new DateTime(2026,7,5,22,15,0,DateTimeKind.Utc);
        db.Appointments.Add(new() {ClientId=client.Id,TherapistId=therapist.Id,
            StartUtc=start,EndUtc=start.AddHours(1),AppointmentDateUtc=start,Status=AppointmentStatus.Pending});
        await db.SaveChangesAsync();
        using var http = factory.CreateAuthenticatedClient(userId,RoleConstants.Client);
        var response = await http.GetAsync($"/api/Appointments/therapist/{therapist.Id}/occupied-slots?date=2026-07-06");
        Assert.Equal(HttpStatusCode.OK,response.StatusCode);
        Assert.Contains("2026-07-05T22:15:00Z",await response.Content.ReadAsStringAsync());
        var occupied = await response.Content.ReadFromJsonAsync<List<OccupiedAppointmentSlotDto>>();
        Assert.Equal(start,Assert.Single(occupied!).StartUtc);
        var previous = await http.GetFromJsonAsync<List<OccupiedAppointmentSlotDto>>($"/api/Appointments/therapist/{therapist.Id}/occupied-slots?date=2026-07-05");
        Assert.Empty(previous!);
    }

    [Fact]
    public async Task CreateApi_RejectsTimestampsWithoutUtcZoneAsValidationError()
    {
        const int userId = 908102;
        await factory.SeedActiveUserAsync(userId,RoleConstants.Client,"zone-validation@test.local","Password123!");
        using var http = factory.CreateAuthenticatedClient(userId,RoleConstants.Client);
        http.DefaultRequestHeaders.Add("Idempotency-Key",Guid.NewGuid().ToString());
        var response = await http.PostAsJsonAsync("/api/Appointments",new {
            therapistId=1,startUtc="2030-07-01T09:00:00",endUtc="2030-07-01T10:00:00",type=1});
        Assert.Equal(HttpStatusCode.BadRequest,response.StatusCode);
        Assert.Contains("UTC",await response.Content.ReadAsStringAsync());
    }
}
