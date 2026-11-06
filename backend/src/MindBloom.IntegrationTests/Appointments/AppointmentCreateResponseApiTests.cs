using System.Net;
using System.Net.Http.Json;
using System.Reflection;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.Idempotency;

namespace MindBloom.IntegrationTests.Appointments;

// Real MVC controller/filter and production mapper; only SQL-dependent creation is
// replaced by synthetic EF InMemory persistence. Does not run Program or hosted jobs.
public sealed class AppointmentCreateResponseApiTests
{
    [Theory]
    [InlineData(AppointmentType.Online)]
    [InlineData(AppointmentType.InPerson)]
    public async Task Created_response_and_same_key_replay_preserve_reserved_values_without_duplicates(AppointmentType type)
    {
        using var host = new LifecycleHost("Success");
        var booking = (BookingDependencyDouble)host.Server.Services.GetRequiredService<IAppointmentService>();
        booking.InvokeBooking = async () =>
        {
            host.State.BookingCalls++;
            using var scope = host.Server.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal("Microsoft.EntityFrameworkCore.InMemory", db.Database.ProviderName);
            var client = new Client { Id = 71, UserId = 900001,
                User = new() { Id = 900001, UserName = "synthetic-client", FirstName = "Synthetic", LastName = "Client", Email = "client@example.invalid" } };
            var therapist = new Therapist { Id = 81, UserId = 900002, HourlyRate = 50.25m, Biography = "Synthetic biography", Specialization = "Synthetic specialization",
                User = new() { Id = 900002, UserName = "synthetic-therapist", FirstName = "Synthetic", LastName = "Therapist" } };
            var start = new DateTime(2030, 1, 1, 9, 0, 0, DateTimeKind.Utc);
            var appointment = new Appointment { Client = client, ClientId = client.Id, Therapist = therapist, TherapistId = therapist.Id,
                Price = 50.25m, Status = AppointmentStatus.Pending, Type = type, StartUtc = start, EndUtc = start.AddHours(1),
                Notes = "Synthetic notes", Location = type == AppointmentType.InPerson ? "Synthetic office" : null };
            db.Appointments.Add(appointment);
            await db.SaveChangesAsync();
            return (AppointmentResponseDto)typeof(AppointmentService)
                .GetMethod("MapCreatedAppointment", BindingFlags.NonPublic | BindingFlags.Static)!
                .Invoke(null, new object[] { appointment, client, therapist })!;
        };
        var payload = new CreateAppointmentDto { TherapistId = 81, Type = type,
            StartUtc = new DateTime(2030, 1, 1, 9, 0, 0, DateTimeKind.Utc),
            EndUtc = new DateTime(2030, 1, 1, 10, 0, 0, DateTimeKind.Utc),
            Notes = "Synthetic notes", Location = type == AppointmentType.InPerson ? "Synthetic office" : null };
        var raw = JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        var key = Guid.NewGuid().ToString("N");
        using var first = await host.Send(key, raw: raw);
        Assert.True(first.StatusCode == HttpStatusCode.OK, string.Join(Environment.NewLine, host.Logs.Rows.Where(x => x.Exception != null).Select(x => x.Exception!.ToString())));
        var body = await first.Content.ReadAsStringAsync();
        var dto = await first.Content.ReadFromJsonAsync<AppointmentResponseDto>();
        Assert.NotNull(dto);
        Assert.True(dto.Id > 0);
        Assert.Equal(71, dto.ClientId);
        Assert.Equal(81, dto.TherapistId);
        Assert.Equal(50.25m, dto.Price);
        Assert.Equal("Pending", dto.Status);
        Assert.Equal(type.ToString(), dto.Type);
        Assert.Equal(payload.StartUtc, dto.StartUtc);
        Assert.Equal(payload.EndUtc, dto.EndUtc);
        Assert.Equal("client@example.invalid", dto.ClientEmail);

        using (var scope = host.Server.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var stored = Assert.Single(await db.Appointments.AsNoTracking().ToListAsync());
            Assert.Equal(stored.Id, dto.Id);
            Assert.Equal(stored.Price, dto.Price);
            var therapist = await db.Therapists.SingleAsync();
            therapist.HourlyRate = 99.75m;
            await db.SaveChangesAsync();
            Assert.Equal(50.25m, (await db.Appointments.AsNoTracking().SingleAsync()).Price);
        }
        using var replay = await host.Send(key, raw: raw);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(body, await replay.Content.ReadAsStringAsync());
        Assert.Equal(1, host.State.BookingCalls);
        using var verify = host.Server.Services.CreateScope();
        var context = verify.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var reserved = Assert.Single(await context.Appointments.AsNoTracking().ToListAsync());
        Assert.Equal(50.25m, reserved.Price);
        Assert.Equal(99.75m, (await context.Therapists.AsNoTracking().SingleAsync()).HourlyRate);
        Assert.Empty(await context.Payments.ToListAsync());
        var record = Assert.Single(await context.ApiIdempotencyRecords.AsNoTracking().ToListAsync());
        Assert.Equal("Completed", record.Status);
        Assert.Equal(200, record.ResponseStatusCode);
        Assert.Equal(body, record.ResponseBody);
    }
}
