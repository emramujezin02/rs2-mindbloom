using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Shared.Constants;
using MindBloom.Shared.Observability;
using Xunit.Abstractions;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class AppointmentBookingRuleSqlTests(MindBloomEndToEndTestFactory factory, ITestOutputHelper output)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    private static int _actor;
    private static readonly DateTime Start = DateTime.UtcNow.Date.AddDays(14).AddHours(10);

    [Theory]
    [InlineData("pending")]
    [InlineData("requires-changes")]
    [InlineData("rejected")]
    [InlineData("inactive")]
    [InlineData("blocked")]
    [InlineData("deleted")]
    [InlineData("missing")]
    public async Task DirectApi_RejectsIneligibleTherapistWithoutBookingSideEffects(string state)
    {
        using var scenario=await SeedAsync();
        using(var scope=factory.Services.CreateScope())
        {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var therapist=await db.Therapists.Include(x=>x.User).SingleAsync(x=>x.Id==scenario.Therapists[0]);
            switch(state)
            {
                case "pending": therapist.VerificationStatus=TherapistVerificationStatus.Pending; break;
                case "requires-changes": therapist.VerificationStatus=TherapistVerificationStatus.RequiresChanges; break;
                case "rejected": therapist.VerificationStatus=TherapistVerificationStatus.Rejected; break;
                case "inactive": therapist.User.IsActive=false; break;
                case "blocked": therapist.User.IsBlocked=true; break;
                case "deleted": therapist.IsDeleted=true; break;
            }
            await db.SaveChangesAsync();
        }
        var before=await SnapshotAsync();
        using var response=await BookAsync(scenario.Actors[0],state=="missing"?int.MaxValue:scenario.Therapists[0],Start);
        Assert.Equal(state=="missing"?HttpStatusCode.NotFound:HttpStatusCode.Conflict,response.StatusCode);
        Assert.DoesNotContain("SQL",await response.Content.ReadAsStringAsync(),StringComparison.OrdinalIgnoreCase);
        Assert.Equal(before,await SnapshotAsync());
    }

    [Theory]
    [InlineData(AppointmentStatus.Pending,0,60,30,false)]
    [InlineData(AppointmentStatus.Accepted,0,60,30,false)]
    [InlineData(AppointmentStatus.Pending,0,60,0,false)]
    [InlineData(AppointmentStatus.Pending,0,120,30,false)]
    [InlineData(AppointmentStatus.Pending,30,60,0,false)]
    [InlineData(AppointmentStatus.Pending,0,60,60,true)]
    [InlineData(AppointmentStatus.Pending,60,120,0,true)]
    [InlineData(AppointmentStatus.Rejected,0,60,30,true)]
    [InlineData(AppointmentStatus.Cancelled,0,60,30,true)]
    [InlineData(AppointmentStatus.Completed,0,60,30,true)]
    public async Task DirectApi_ClientOverlapAcrossTherapistsUsesHalfOpenUtcIntervals(
        AppointmentStatus status,int existingStart,int existingEnd,int requestedStart,bool succeeds)
    {
        using var scenario=await SeedAsync();
        await AddExistingAsync(scenario,Start.AddMinutes(existingStart),Start.AddMinutes(existingEnd),status);
        var before=await SnapshotAsync();
        using var response=await BookAsync(scenario.Actors[0],scenario.Therapists[1],Start.AddMinutes(requestedStart));
        Assert.Equal(succeeds?HttpStatusCode.OK:HttpStatusCode.Conflict,response.StatusCode);
        if(succeeds) await AssertCreatedAsync(before,1);
        else
        {
            Assert.Contains("already have an active appointment",await response.Content.ReadAsStringAsync());
            Assert.Equal(before,await SnapshotAsync());
        }
    }

    [Theory]
    [InlineData(1,4,10,30)]
    [InlineData(7,5,22,15)]
    public async Task ClientOverlap_UsesInstantsInWinterAndAcrossLocalMidnight(int month,int day,int hour,int minute)
    {
        using var scenario=await SeedAsync();
        var utc=new DateTime(DateTime.UtcNow.Year+1,month,day,hour,minute,0,DateTimeKind.Utc);
        await AddExistingAsync(scenario,utc.AddMinutes(-30),utc.AddMinutes(30),AppointmentStatus.Accepted);
        var before=await SnapshotAsync();
        using var response=await BookAsync(scenario.Actors[0],scenario.Therapists[1],utc);
        Assert.Equal(HttpStatusCode.Conflict,response.StatusCode);
        Assert.Equal(before,await SnapshotAsync());
    }

    [Fact]
    public async Task RepeatedIdenticalApiRequest_ReplaysOnlyOneBookingAndOneOutboxEvent()
    {
        using var scenario=await SeedAsync(); var before=await SnapshotAsync(); var key=Guid.NewGuid().ToString();
        using var first=await BookAsync(scenario.Actors[0],scenario.Therapists[0],Start,key);
        using var second=await BookAsync(scenario.Actors[0],scenario.Therapists[0],Start,key);
        Assert.Equal(HttpStatusCode.OK,first.StatusCode); Assert.Equal(HttpStatusCode.OK,second.StatusCode);
        Assert.Equal(await first.Content.ReadAsStringAsync(),await second.Content.ReadAsStringAsync());
        using var differentKey=await BookAsync(scenario.Actors[0],scenario.Therapists[0],Start);
        Assert.Equal(HttpStatusCode.Conflict,differentKey.StatusCode);
        await AssertCreatedAsync(before,1);
    }

    [Fact]
    public async Task DirectApi_TwoHourRequestContainingExistingAppointmentKeepsOneHourValidation()
    {
        using var scenario=await SeedAsync();
        await AddExistingAsync(scenario,Start.AddMinutes(30),Start.AddMinutes(90),AppointmentStatus.Pending);
        var before=await SnapshotAsync();
        using var request=new HttpRequestMessage(HttpMethod.Post,"/api/Appointments")
        {
            Content=JsonContent.Create(new CreateAppointmentDto {TherapistId=scenario.Therapists[1],
                StartUtc=Start,EndUtc=Start.AddHours(2),Type=AppointmentType.Online})
        };
        request.Headers.Add(factory.GetIdempotencyHeaderName(),Guid.NewGuid().ToString());
        using var response=await scenario.Actors[0].SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest,response.StatusCode);
        Assert.Contains("exactly one hour",await response.Content.ReadAsStringAsync());
        Assert.Equal(before,await SnapshotAsync());
    }

    [Theory]
    [InlineData("same-client",2)]
    [InlineData("same-therapist",2)]
    [InlineData("many",8)]
    [Trait("Category","BookingConcurrency")]
    public async Task ParallelHttpBookings_CreateExactlyOneAppointment(string scenarioName,int requests)
    {
        using var scenario=await SeedAsync(); var before=await SnapshotAsync();
        var gate=new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var tasks=Enumerable.Range(0,requests).Select(async index=>
        {
            await gate.Task;
            var actor=scenarioName=="same-therapist"?index%2:0;
            var therapist=scenarioName=="same-therapist"?0:index%2;
            return await BookAsync(scenario.Actors[actor],scenario.Therapists[therapist],Start.AddMinutes(index%2*30));
        }).ToArray();
        gate.SetResult(true); var responses=await Task.WhenAll(tasks);
        try
        {
            Assert.Single(responses,x=>x.StatusCode==HttpStatusCode.OK);
            Assert.Equal(requests-1,responses.Count(x=>x.StatusCode==HttpStatusCode.Conflict));
            foreach(var response in responses.Where(x=>x.StatusCode!=HttpStatusCode.OK))
            {
                using var problem=JsonDocument.Parse(await response.Content.ReadAsStringAsync());
                Assert.Equal("business_rule_violation",problem.RootElement.GetProperty("errorCode").GetString());
                Assert.Contains("already",problem.RootElement.GetProperty("detail").GetString());
                Assert.DoesNotContain("deadlock",await response.Content.ReadAsStringAsync(),StringComparison.OrdinalIgnoreCase);
                Assert.DoesNotContain("busy",await response.Content.ReadAsStringAsync(),StringComparison.OrdinalIgnoreCase);
            }
            await AssertCreatedAsync(before,1);
            using var scope=factory.Services.CreateScope();
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var winning=await db.Appointments.SingleAsync(x=>scenario.Clients.Contains(x.ClientId));
            var memberships=await db.ClientMemberships.Where(x=>scenario.Clients.Contains(x.ClientId)).ToListAsync();
            Assert.All(memberships,x=>Assert.Equal(10,x.RemainingSessions));
            // Creation never consumes membership. Use the existing accepted-appointment flow once.
            var service=scope.ServiceProvider.GetRequiredService<IAppointmentService>();
            var therapistUserId=await db.Therapists.Where(x=>x.Id==winning.TherapistId).Select(x=>x.UserId).SingleAsync();
            await service.UpdateStatusAsync(therapistUserId,new() {AppointmentId=winning.Id,Status=AppointmentStatus.Accepted});
            var clientUserId=await db.Clients.Where(x=>x.Id==winning.ClientId).Select(x=>x.UserId).SingleAsync();
            await scope.ServiceProvider.GetRequiredService<IMembershipService>().UseMembershipAsync(clientUserId,new UseMembershipDto {AppointmentId=winning.Id});
            db.ChangeTracker.Clear();
            Assert.Equal(1,await db.MembershipUsages.CountAsync(x=>x.AppointmentId==winning.Id));
            Assert.Equal(memberships.Count*10-1,await db.ClientMemberships.Where(x=>scenario.Clients.Contains(x.ClientId)).SumAsync(x=>x.RemainingSessions));
            output.WriteLine($"{scenarioName}: success=1 conflict={requests-1} active=1 bookingOutbox=1; sessions 40->40 on create, 40->39 on accepted membership use; usage=1; no SQL error/timeout response.");
        }
        finally {foreach(var response in responses)response.Dispose();}
    }

    private async Task<Scenario> SeedAsync()
    {
        var actors=new List<HttpClient>(); var users=new List<int>();
        for(var i=0;i<2;i++)
        {
            var email=$"booking-rule-{Guid.NewGuid():N}@test.local"; const string password="BookingRules123!";
            users.Add(await factory.SeedActiveUserAsync(RoleConstants.Client,email,password));
            var address=IPAddress.Parse($"2001:db8:11::{Interlocked.Increment(ref _actor):x}");
            using var anonymous=new HttpClient(factory.Server.CreateHandler(c=>c.Connection.RemoteIpAddress=address)) {BaseAddress=new Uri("http://localhost")};
            var response=await anonymous.PostAsJsonAsync("/api/Auth/login-2fa",new LoginRequestDto {Email=email,Password=password});
            Assert.Equal(HttpStatusCode.OK,response.StatusCode);
            var auth=await response.Content.ReadFromJsonAsync<Login2FAResponseDto>();
            var actor=new HttpClient(factory.Server.CreateHandler(c=>c.Connection.RemoteIpAddress=address)) {BaseAddress=new Uri("http://localhost")};
            actor.DefaultRequestHeaders.Authorization=new("Bearer",auth!.Auth!.Token); actors.Add(actor);
        }
        using var scope=factory.Services.CreateScope(); var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var clients=users.Select(id=>new Client {UserId=id}).ToArray();
        var therapists=Enumerable.Range(0,2).Select(_=>new Therapist {User=new() {UserName=$"booking-therapist-{Guid.NewGuid():N}",FirstName="Booking",LastName="Test",IsActive=true},
            Biography="Synthetic test",Specialization="Test",VerificationStatus=TherapistVerificationStatus.Approved,HourlyRate=50}).ToArray();
        db.AddRange(clients);db.AddRange(therapists);await db.SaveChangesAsync();
        foreach(var therapist in therapists)
        foreach(var day in Enum.GetValues<DayOfWeek>())
            db.TherapistAvailabilities.Add(new() {TherapistId=therapist.Id,DayOfWeek=day,StartTime=TimeSpan.Zero,EndTime=new TimeSpan(23,59,59)});
        foreach(var client in clients)
        foreach(var therapist in therapists)
        {
            var membership=new ClientMembership {ClientId=client.Id,TherapistId=therapist.Id,PlanType=MembershipPlanType.TenSessions,
                TotalSessions=10,RemainingSessions=10,Price=500,DurationMonths=6,IsActive=true,PurchasedAtUtc=DateTime.UtcNow,ExpiresAtUtc=DateTime.UtcNow.AddMonths(6)};
            membership.Payment=new() {Status=PaymentStatus.Paid,Amount=500,StripePaymentIntentId=$"pi_synthetic_{Guid.NewGuid():N}"};
            db.Add(membership);
        }
        await db.SaveChangesAsync();
        return new(actors.ToArray(),clients.Select(x=>x.Id).ToArray(),therapists.Select(x=>x.Id).ToArray());
    }

    [Fact]
    [Trait("Category","BookingConcurrency")]
    public async Task IndependentClientsAndTherapists_CanBookConcurrentlyWithoutFalseConflicts()
    {
        using var scenario=await SeedAsync(); var before=await SnapshotAsync();
        var deadlocksBefore=await DeadlockCountAsync();
        var gate=new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var tasks=Enumerable.Range(0,2).Select(async index=>
        {
            await gate.Task;
            return await BookAsync(scenario.Actors[index],scenario.Therapists[index],Start);
        }).ToArray();
        gate.SetResult(true);var responses=await Task.WhenAll(tasks);
        try
        {
            var deadlocksAfter=await DeadlockCountAsync();
            output.WriteLine($"SQL deadlock events before={deadlocksBefore}, after={deadlocksAfter}");
            foreach(var response in responses)
                Assert.True(response.StatusCode==HttpStatusCode.OK,
                    $"Unexpected status {response.StatusCode}: {await response.Content.ReadAsStringAsync()}");
            Assert.Equal(deadlocksBefore,deadlocksAfter);
            await AssertCreatedAsync(before,2);
            output.WriteLine("independent: success=2 conflict=0 active=2 bookingOutbox=2; memberships unchanged.");
        }
        finally {foreach(var response in responses)response.Dispose();}
    }

    private async Task<int> DeadlockCountAsync()
    {
        using var scope=factory.Services.CreateScope();
        var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        return await db.Database.SqlQueryRaw<int>("""
            SELECT CAST(t.target_data AS xml).value('count(/RingBufferTarget/event[@name="xml_deadlock_report"])','int') AS [Value]
            FROM sys.dm_xe_sessions s JOIN sys.dm_xe_session_targets t ON t.event_session_address=s.address
            WHERE s.name=N'system_health' AND t.target_name=N'ring_buffer'
            """).SingleAsync();
    }

    [Fact]
    public async Task FailureAfterSavingOutbox_RollsBackAppointmentAuditAndEventAndReleasesLocks()
    {
        using var scenario=await SeedAsync(); var before=await SnapshotAsync();
        int userId;
        using(var scope=factory.Services.CreateScope())
        {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            userId=await db.Clients.Where(x=>x.Id==scenario.Clients[0]).Select(x=>x.UserId).SingleAsync();
            var service=new AppointmentService(db,scope.ServiceProvider.GetRequiredService<IPaymentService>(),
                scope.ServiceProvider.GetRequiredService<IMembershipService>(),scope.ServiceProvider.GetRequiredService<ApplicationMetrics>(),
                scope.ServiceProvider.GetRequiredService<IIntegrationEventPublisher>(),
                new FailingOutbox(db,scope.ServiceProvider.GetRequiredService<IOutboxWriter>()));
            await Assert.ThrowsAsync<InvalidOperationException>(()=>service.CreateAsync(userId,new()
                {TherapistId=scenario.Therapists[0],StartUtc=Start,EndUtc=Start.AddHours(1),Type=AppointmentType.Online}));
        }
        Assert.Equal(before,await SnapshotAsync());
        using var retry=await BookAsync(scenario.Actors[0],scenario.Therapists[0],Start);
        Assert.Equal(HttpStatusCode.OK,retry.StatusCode);
        await AssertCreatedAsync(before,1);
    }

    [Fact]
    public async Task ClientLockTimeout_ReturnsBusinessConflictAndAllowsRetryAfterRelease()
    {
        using var scenario=await SeedAsync(); var before=await SnapshotAsync();
        using(var scope=factory.Services.CreateScope())
        {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userId=await db.Clients.Where(x=>x.Id==scenario.Clients[0]).Select(x=>x.UserId).SingleAsync();
            await using var tx=await db.Database.BeginTransactionAsync();
            var resource=$"MindBloom.AppointmentBooking.ClientUser.{userId}";
            await db.Database.ExecuteSqlInterpolatedAsync($"EXEC sp_getapplock @Resource={resource}, @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=1000");
            using var response=await BookAsync(scenario.Actors[0],scenario.Therapists[0],Start);
            Assert.Equal(HttpStatusCode.Conflict,response.StatusCode);
            Assert.Contains("booking is busy",await response.Content.ReadAsStringAsync());
            Assert.DoesNotContain("SQL",await response.Content.ReadAsStringAsync(),StringComparison.OrdinalIgnoreCase);
            await tx.RollbackAsync();
        }
        Assert.Equal(before,await SnapshotAsync());
        using var retry=await BookAsync(scenario.Actors[0],scenario.Therapists[0],Start);
        Assert.Equal(HttpStatusCode.OK,retry.StatusCode);
        await AssertCreatedAsync(before,1);
    }

    private sealed class FailingOutbox(ApplicationDbContext db,IOutboxWriter inner):IOutboxWriter
    {
        public async Task EnqueueAsync<TEvent>(TEvent integrationEvent,string routingKey,CancellationToken cancellationToken=default,string? idempotencyKey=null)
            where TEvent:IntegrationEvent
        {
            await inner.EnqueueAsync(integrationEvent,routingKey,cancellationToken,idempotencyKey);
            await db.SaveChangesAsync(cancellationToken);
            throw new InvalidOperationException("Synthetic failure after transactional outbox save.");
        }
    }

    private async Task AddExistingAsync(Scenario s,DateTime start,DateTime end,AppointmentStatus status)
    {
        using var scope=factory.Services.CreateScope();var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        db.Appointments.Add(new() {ClientId=s.Clients[0],TherapistId=s.Therapists[0],StartUtc=start,EndUtc=end,AppointmentDateUtc=start,Status=status,Type=AppointmentType.Online});
        await db.SaveChangesAsync();
    }

    private Task<HttpResponseMessage> BookAsync(HttpClient actor,int therapistId,DateTime start,string? key=null)
    {
        var message=new HttpRequestMessage(HttpMethod.Post,"/api/Appointments")
            {Content=JsonContent.Create(new CreateAppointmentDto {TherapistId=therapistId,StartUtc=start,EndUtc=start.AddHours(1),Type=AppointmentType.Online})};
        message.Headers.Add(factory.GetIdempotencyHeaderName(),key??Guid.NewGuid().ToString());
        return actor.SendAsync(message);
    }

    private async Task<Snapshot> SnapshotAsync()
    {
        using var scope=factory.Services.CreateScope();var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        return new(await db.Appointments.CountAsync(),await db.AppointmentStatusAudits.CountAsync(),await db.OutboxMessages.CountAsync(),
            await db.MembershipUsages.CountAsync(),await db.ClientMemberships.SumAsync(x=>x.RemainingSessions),await db.Notifications.CountAsync(),await db.Payments.CountAsync());
    }

    private async Task AssertCreatedAsync(Snapshot before,int count)
    {
        var after=await SnapshotAsync();
        Assert.Equal(before with {Appointments=before.Appointments+count,Audits=before.Audits+count,Outbox=before.Outbox+count},after);
    }
    private sealed record Snapshot(int Appointments,int Audits,int Outbox,int Usage,int Sessions,int Notifications,int Payments);
    private sealed record Scenario(HttpClient[] Actors,int[] Clients,int[] Therapists):IDisposable
    {
        public void Dispose() {foreach(var actor in Actors)actor.Dispose();}
    }
}
