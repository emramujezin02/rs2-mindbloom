using System.Net;
using System.Net.Http.Json;
using System.Reflection;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.API.Messaging.Outbox;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Handlers;
using MindBloom.NotificationsWorker.Handlers.Appointments;
using MindBloom.NotificationsWorker.Services;
using MindBloom.Shared.Constants;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class NotificationPollingSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Fact]
    public async Task BookingOutboxWorker_NotificationVisibleOnNextAuthenticatedPoll_OnlyForRecipient()
    {
        const string password = "NotificationTest123!";
        var clientEmail = $"poll-client-{Guid.NewGuid():N}@test.local";
        var therapistEmail = $"poll-therapist-{Guid.NewGuid():N}@test.local";
        var otherEmail = $"poll-other-{Guid.NewGuid():N}@test.local";
        var clientUser = await factory.SeedActiveUserAsync(RoleConstants.Client, clientEmail, password);
        var therapistUser = await factory.SeedActiveUserAsync(RoleConstants.Therapist, therapistEmail, password);
        var otherUser = await factory.SeedActiveUserAsync(RoleConstants.Therapist, otherEmail, password);
        int therapistId;
        using (var seed = factory.Services.CreateScope())
        {
            var db = seed.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var client = new Client { UserId = clientUser };
            var therapist = new Therapist { UserId = therapistUser, VerificationStatus = TherapistVerificationStatus.Approved,
                Biography = "Synthetic test", Specialization = "Test", HourlyRate = 80, OffersOnline = true };
            db.AddRange(client, therapist);
            await db.SaveChangesAsync();
            therapistId = therapist.Id;
            foreach (var day in Enum.GetValues<DayOfWeek>())
                db.TherapistAvailabilities.Add(new() { TherapistId = therapistId, DayOfWeek = day,
                    StartTime = TimeSpan.Zero, EndTime = new TimeSpan(23, 59, 59) });
            var membership = new ClientMembership { ClientId = client.Id, TherapistId = therapist.Id,
                PlanType = MembershipPlanType.TenSessions, TotalSessions = 10, RemainingSessions = 10,
                Price = 500, DurationMonths = 6, IsActive = true, PurchasedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddMonths(6), Payment = new() { Status = PaymentStatus.Paid,
                    Amount = 500, StripePaymentIntentId = $"pi_synthetic_{Guid.NewGuid():N}" } };
            db.Add(membership);
            await db.SaveChangesAsync();
        }
        using var therapistHttp = await Login(therapistEmail, therapistUser);
        using var clientHttp = await Login(clientEmail, clientUser);
        using var otherHttp = await Login(otherEmail, otherUser);
        var before = await Poll(therapistHttp);
        Assert.Empty(before.GetProperty("items").EnumerateArray());
        var start = DateTime.UtcNow.Date.AddDays(14).AddHours(10);
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/Appointments") {
            Content = JsonContent.Create(new CreateAppointmentDto { TherapistId = therapistId,
                StartUtc = start, EndUtc = start.AddHours(1), Type = AppointmentType.Online }) };
        request.Headers.Add(factory.GetIdempotencyHeaderName(), Guid.NewGuid().ToString());
        using var booked = await clientHttp.SendAsync(request);
        Assert.True(booked.StatusCode == HttpStatusCode.OK, await booked.Content.ReadAsStringAsync());
        var publisher = factory.Services.GetRequiredService<TestIntegrationEventPublisher>();
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var appointment = await context.Appointments.AsNoTracking().SingleAsync(x => x.TherapistId == therapistId);
        Assert.Equal(AppointmentStatus.Pending, appointment.Status);
        Assert.Empty((await Poll(therapistHttp)).GetProperty("items").EnumerateArray());
        Assert.DoesNotContain(publisher.Events, x => x.Event is AppointmentCreatedEvent);

        // Execute the existing outbox processor after the booking committed.
        using var processor = new OutboxMessageProcessor(factory.Services.GetRequiredService<IServiceScopeFactory>(),
            NullLogger<OutboxMessageProcessor>.Instance);
        var process = typeof(OutboxMessageProcessor).GetMethod("ProcessBatchAsync", BindingFlags.NonPublic | BindingFlags.Instance)!;
        await (Task<bool>)process.Invoke(processor, new object[] { CancellationToken.None })!;
        var created = Assert.Single(publisher.Events.Select(x => x.Event).OfType<AppointmentCreatedEvent>());
        Assert.Equal(appointment.Id, created.AppointmentId);

        // Real Worker dispatcher/handler and SQL persistence; email/push and the
        // RabbitMQ transport are substitutes, not external delivery in this test.
        await using var worker = new ServiceCollection()
            .AddSingleton(scope.ServiceProvider.GetRequiredService<DbContextOptions<ApplicationDbContext>>())
            .AddScoped<ApplicationDbContext>()
            .AddScoped(sp => new WorkerNotificationService(sp.GetRequiredService<ApplicationDbContext>(),
                new NoEmail(), new NoPush(), new ApplicationMetrics(), NullLogger<WorkerNotificationService>.Instance))
            .AddScoped<IIntegrationEventHandler<AppointmentCreatedEvent>, AppointmentCreatedEventHandler>()
            .BuildServiceProvider();
        var dispatcher = new IntegrationEventDispatcher(worker.GetRequiredService<IServiceScopeFactory>(),
            NullLogger<IntegrationEventDispatcher>.Instance);
        var inbox = new ProcessedMessageService(context, NullLogger<ProcessedMessageService>.Instance);
        for (var delivery = 0; delivery < 2; delivery++)
        {
            if (await inbox.IsProcessedAsync(created.EventId, "IntegrationEventConsumer")) continue;
            await dispatcher.DispatchAsync(created, CancellationToken.None);
            await inbox.MarkAsProcessedAsync(created.EventId, "IntegrationEventConsumer", nameof(AppointmentCreatedEvent), created.CorrelationId);
        }
        var after = await Poll(therapistHttp);
        var row = Assert.Single(after.GetProperty("items").EnumerateArray());
        Assert.Equal("New appointment request", row.GetProperty("title").GetString());
        Assert.Equal(appointment.Id, row.GetProperty("appointmentId").GetInt32());
        Assert.Equal(1, after.GetProperty("unreadCount").GetInt32());
        Assert.Single(await context.Notifications.AsNoTracking().ToListAsync());
        var other = await Poll(otherHttp, $"&userId={therapistUser}");
        Assert.Empty(other.GetProperty("items").EnumerateArray());
        var id = row.GetProperty("id").GetInt32();
        Assert.Equal(HttpStatusCode.NotFound, (await otherHttp.PutAsync($"/api/Notifications/{id}/read", null)).StatusCode);
        using var anonymous = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/Notifications")).StatusCode);

        var export = Environment.GetEnvironmentVariable("TASK18_NOTIFICATION_FIXTURE");
        if (!string.IsNullOrWhiteSpace(export))
        {
            await File.WriteAllTextAsync(export, JsonSerializer.Serialize(new { before, after, otherUser = other }));
        }
        Assert.Equal(HttpStatusCode.OK, (await therapistHttp.PutAsync($"/api/Notifications/{id}/read", null)).StatusCode);
        Assert.Equal(0, (await Poll(therapistHttp)).GetProperty("unreadCount").GetInt32());
    }

    private static async Task<JsonElement> Poll(HttpClient client, string suffix = "")
    {
        using var response = await client.GetAsync("/api/Notifications?pageNumber=1&pageSize=20" + suffix);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement.Clone();
    }
    private async Task<HttpClient> Login(string email, int id)
    {
        using var anonymous = new HttpClient(factory.Server.CreateHandler(c => c.Connection.RemoteIpAddress = IPAddress.Parse($"2001:db8:18::{id:x}"))) { BaseAddress = new Uri("http://localhost") };
        using var response = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto { Email = email, Password = "NotificationTest123!" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return factory.CreateBearerClient((await response.Content.ReadFromJsonAsync<Login2FAResponseDto>())!.Auth!.Token);
    }
    private sealed class NoEmail : IEmailService { public Task SendAsync(string to, string subject, string body) => Task.CompletedTask; }
    private sealed class NoPush : IPushNotificationService
    {
        public Task SendToUserAsync(int id, string title, string message, IReadOnlyDictionary<string, string>? data = null, CancellationToken ct = default) => Task.CompletedTask;
    }
}
