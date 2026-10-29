using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Time;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class TherapistDailyOverviewSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Theory]
    [InlineData(AppointmentStatus.Accepted, true)]
    [InlineData(AppointmentStatus.Completed, true)]
    [InlineData(AppointmentStatus.Pending, false)]
    [InlineData(AppointmentStatus.Cancelled, false)]
    [InlineData(AppointmentStatus.Rejected, false)]
    public async Task BasicProfile_UsesExistingRelationshipWithoutPrivateSections(AppointmentStatus status, bool allowed)
    {
        var s = await Seed();
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Appointments.Add(Appointment(s, status, DateTime.UtcNow.AddDays(2), DateTime.UtcNow.AddDays(2).AddHours(1)));
            await db.SaveChangesAsync();
        }
        using var http = await Login(s.TherapistEmail, s.TherapistUser);
        using var result = await http.GetAsync($"/api/Therapists/clients/{s.Client}/profile");
        Assert.Equal(allowed ? HttpStatusCode.OK : HttpStatusCode.NotFound, result.StatusCode);
        if (allowed)
        {
            var json = JsonDocument.Parse(await result.Content.ReadAsStringAsync()).RootElement;
            Assert.Equal(new[] { "clientId", "email", "fullName", "phoneNumber" }, json.EnumerateObject().Select(x => x.Name).Order().ToArray());
            Assert.Equal(s.Client, json.GetProperty("clientId").GetInt32());
            Assert.Equal(s.ClientEmail, json.GetProperty("email").GetString());
        }
        using var verify = factory.Services.CreateScope();
        var dbVerify = verify.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(status, (await dbVerify.Appointments.SingleAsync(x => x.ClientId == s.Client)).Status);
        Assert.False(await dbVerify.AppointmentStatusAudits.AnyAsync(x => x.Appointment.ClientId == s.Client));
    }

    [Fact]
    public async Task BasicProfile_RejectsIdorSpoofedIdentityAnonymousAndWrongRole()
    {
        var owner = await Seed();
        var other = await Seed();
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Appointments.Add(Appointment(owner, AppointmentStatus.Accepted, DateTime.UtcNow.AddDays(2), DateTime.UtcNow.AddDays(2).AddHours(1)));
            await db.SaveChangesAsync();
        }
        using var stranger = await Login(other.TherapistEmail, other.TherapistUser);
        using var unrelated = await stranger.GetAsync($"/api/Therapists/clients/{owner.Client}/profile?therapistUserId={owner.TherapistUser}");
        using var missing = await stranger.GetAsync("/api/Therapists/clients/2147483647/profile");
        Assert.Equal(HttpStatusCode.NotFound, unrelated.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        using var anonymous = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync($"/api/Therapists/clients/{owner.Client}/profile")).StatusCode);
        using var client = await Login(owner.ClientEmail, owner.ClientUser);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/Therapists/clients/{owner.Client}/profile")).StatusCode);
    }

    [Theory]
    [InlineData(3, 29, 23)]
    [InlineData(10, 25, 25)]
    public async Task DailyOverlap_IncludesMidnightCrossingsWithPaginationAndOwnerIsolation(int month, int day, int hours)
    {
        var s = await Seed();
        var other = await Seed();
        var (start, end) = AppointmentTimeZone.DayBounds(new DateTime(2026, month, day));
        Assert.Equal(hours, (end - start).TotalHours);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var previous = Appointment(s, AppointmentStatus.Cancelled, start.AddMinutes(-30), start.AddMinutes(30));
        var inside = Appointment(s, AppointmentStatus.Cancelled, start.AddHours(3), start.AddHours(4));
        var crossing = Appointment(s, AppointmentStatus.Cancelled, end.AddMinutes(-30), end.AddMinutes(30));
        var deleted = Appointment(s, AppointmentStatus.Cancelled, start.AddHours(5), start.AddHours(6));
        deleted.IsDeleted = true;
        db.AddRange(previous, inside, crossing, deleted,
            Appointment(s, AppointmentStatus.Cancelled, start.AddHours(-1), start),
            Appointment(s, AppointmentStatus.Cancelled, end, end.AddHours(1)),
            Appointment(other, AppointmentStatus.Cancelled, start.AddHours(3), start.AddHours(4)));
        await db.SaveChangesAsync();
        var service = scope.ServiceProvider.GetRequiredService<IAppointmentService>();
        var first = await service.GetTherapistAppointmentsAsync(s.TherapistUser, 1, 2, null, start, end, true);
        var second = await service.GetTherapistAppointmentsAsync(s.TherapistUser, 2, 2, null, start, end, true);
        Assert.Equal(3, first.TotalCount);
        Assert.Equal(2, first.TotalPages);
        Assert.Equal(new[] { previous.Id, inside.Id, crossing.Id }, first.Items.Concat(second.Items).Select(x => x.Id).ToArray());
        var legacy = await service.GetTherapistAppointmentsAsync(s.TherapistUser, 1, 50, null, start, end);
        Assert.DoesNotContain(legacy.Items, x => x.Id == previous.Id);
        using var http = await Login(s.TherapistEmail, s.TherapistUser);
        using var response = await http.GetAsync($"/api/Appointments/therapist?overlapsRange=true&pageSize=50&fromUtc={Uri.EscapeDataString(start.ToString("O"))}&toUtc={Uri.EscapeDataString(end.ToString("O"))}&therapistUserId={other.TherapistUser}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var items = JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement.GetProperty("items");
        Assert.Equal(3, items.GetArrayLength());
        Assert.All(items.EnumerateArray(), x => Assert.Equal(s.Therapist, x.GetProperty("therapistId").GetInt32()));
    }

    private async Task<Scenario> Seed()
    {
        var clientEmail = $"daily-client-{Guid.NewGuid():N}@test.local";
        var therapistEmail = $"daily-therapist-{Guid.NewGuid():N}@test.local";
        var clientUser = await factory.SeedActiveUserAsync(RoleConstants.Client, clientEmail, "DailyTest123!");
        var therapistUser = await factory.SeedActiveUserAsync(RoleConstants.Therapist, therapistEmail, "DailyTest123!");
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var client = new Client { UserId = clientUser };
        var therapist = new Therapist { UserId = therapistUser, Biography = "Test", Specialization = "Test" };
        db.AddRange(client, therapist);
        await db.SaveChangesAsync();
        return new(client.Id, clientUser, clientEmail, therapist.Id, therapistUser, therapistEmail);
    }

    private static Appointment Appointment(Scenario s, AppointmentStatus status, DateTime start, DateTime end) =>
        new() { ClientId = s.Client, TherapistId = s.Therapist, Status = status, StartUtc = start, EndUtc = end, AppointmentDateUtc = start };

    private async Task<HttpClient> Login(string email, int id)
    {
        using var anonymous = new HttpClient(factory.Server.CreateHandler(c => c.Connection.RemoteIpAddress = IPAddress.Parse($"2001:db8:17::{id:x}")))
            { BaseAddress = new Uri("http://localhost") };
        using var response = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto { Email = email, Password = "DailyTest123!" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return factory.CreateBearerClient((await response.Content.ReadFromJsonAsync<Login2FAResponseDto>())!.Auth!.Token);
    }

    private sealed record Scenario(int Client, int ClientUser, string ClientEmail, int Therapist, int TherapistUser, string TherapistEmail);
}
