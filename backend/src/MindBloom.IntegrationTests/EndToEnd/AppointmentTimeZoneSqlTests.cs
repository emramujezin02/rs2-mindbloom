using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System.Net;
using System.Net.Http.Json;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Shared.Constants;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class AppointmentTimeZoneSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Theory]
    [InlineData(7, 5, 7)]
    [InlineData(1, 4, 8)]
    public async Task MobileUtcContract_LoginBookAndReadOccupiedThroughHttp(int month, int day, int hour)
    {
        var email = $"booking-zone-{Guid.NewGuid():N}@test.local";
        const string password = "BookingZone123!";
        var userId = await factory.SeedActiveUserAsync(RoleConstants.Client,email,password);
        int therapistId;
        using(var scope=factory.Services.CreateScope())
        {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var therapist=Therapist();
            db.AddRange(new Client {UserId=userId},therapist);
            await db.SaveChangesAsync(); therapistId=therapist.Id;
            db.TherapistAvailabilities.Add(new() {TherapistId=therapistId,DayOfWeek=DayOfWeek.Monday,
                StartTime=TimeSpan.FromHours(9),EndTime=TimeSpan.FromHours(17)});
            await db.SaveChangesAsync();
        }
        using var anonymous=factory.CreateClient();
        var login=await anonymous.PostAsJsonAsync("/api/Auth/login-2fa",new LoginRequestDto {Email=email,Password=password});
        Assert.Equal(HttpStatusCode.OK,login.StatusCode);
        var auth=await login.Content.ReadFromJsonAsync<Login2FAResponseDto>();
        using var http=factory.CreateBearerClient(auth!.Auth!.Token);
        http.DefaultRequestHeaders.Add(factory.GetIdempotencyHeaderName(),Guid.NewGuid().ToString());
        var start=new DateTime(2027,month,day,hour,0,0,DateTimeKind.Utc);
        var created=await http.PostAsJsonAsync("/api/Appointments",new CreateAppointmentDto
            {TherapistId=therapistId,StartUtc=start,EndUtc=start.AddHours(1),Type=AppointmentType.Online});
        Assert.Equal(HttpStatusCode.OK,created.StatusCode);
        var appointment=await created.Content.ReadFromJsonAsync<AppointmentResponseDto>();
        Assert.Equal(start,appointment!.StartUtc);
        var slots=await http.GetFromJsonAsync<List<OccupiedAppointmentSlotDto>>(
            $"/api/Appointments/therapist/{therapistId}/occupied-slots?date=2027-{month:00}-{day:00}");
        Assert.Equal(start,Assert.Single(slots!).StartUtc);
    }

    [Theory]
    [InlineData(7, 6, 7)]
    [InlineData(1, 5, 8)]
    public async Task SarajevoNineToSeventeen_BooksUtcAndReportsCorrectLocalDay(int month, int day, int utcHour)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var service = scope.ServiceProvider.GetRequiredService<IAppointmentService>();
        var client = new Client {User = User()};
        var therapist = Therapist();
        db.AddRange(client, therapist);
        await db.SaveChangesAsync();
        db.TherapistAvailabilities.Add(new() {TherapistId = therapist.Id,
            DayOfWeek = DayOfWeek.Monday, StartTime = TimeSpan.FromHours(9), EndTime = TimeSpan.FromHours(17)});
        await db.SaveChangesAsync();
        var start = new DateTime(2026, month, day, utcHour, 0, 0, DateTimeKind.Utc);
        CreateAppointmentDto Request(DateTime utc) => new() {TherapistId = therapist.Id,
            StartUtc = utc, EndUtc = utc.AddHours(1), Type = AppointmentType.Online};

        var first = await service.CreateAsync(client.UserId, Request(start));
        var last = await service.CreateAsync(client.UserId, Request(start.AddHours(7)));
        Assert.Equal(start, first.StartUtc);
        Assert.Equal(start.AddHours(8), last.EndUtc);
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(client.UserId, Request(start.AddHours(-1))));
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(client.UserId, Request(start.AddHours(8))));
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(client.UserId, Request(start)));
        var occupied = await service.GetOccupiedSlotsAsync(therapist.Id, new DateTime(2026, month, day));
        Assert.Equal(2, occupied.Count);
        Assert.All(occupied, x => Assert.Equal(DateTimeKind.Utc, x.StartUtc.Kind));
        Assert.Empty(await service.GetOccupiedSlotsAsync(therapist.Id, new DateTime(2026, month, day).AddDays(-1)));
        Assert.Empty(await service.GetOccupiedSlotsAsync(therapist.Id, new DateTime(2026, month, day).AddDays(1)));
        db.ChangeTracker.Clear();
        Assert.Equal(start, (await db.Appointments.SingleAsync(x => x.Id == first.Id)).StartUtc);
        Assert.Equal(2, await db.AppointmentStatusAudits.CountAsync(x => x.Appointment.TherapistId == therapist.Id));
    }

    [Theory]
    [InlineData(3, 29, 23)]
    [InlineData(10, 25, 25)]
    [InlineData(7, 6, 24)]
    public async Task OccupiedSlots_UseLocalHalfOpenDayAndIncludeCrossMidnightIntervals(int month, int day, int hours)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var service = scope.ServiceProvider.GetRequiredService<IAppointmentService>();
        var client = new Client {User = User()};
        var therapist = Therapist();
        db.AddRange(client, therapist); await db.SaveChangesAsync();
        var date = new DateTime(2026, month, day);
        var zone = MindBloom.Infrastructure.Time.AppointmentTimeZone.Zone;
        var start = TimeZoneInfo.ConvertTimeToUtc(date, zone);
        var end = TimeZoneInfo.ConvertTimeToUtc(date.AddDays(1), zone);
        Assert.Equal(hours, (end-start).TotalHours);
        void Add(DateTime a, DateTime b, AppointmentStatus status = AppointmentStatus.Pending) =>
            db.Appointments.Add(new() {ClientId=client.Id,TherapistId=therapist.Id,
                StartUtc=a,EndUtc=b,AppointmentDateUtc=a,Status=status,Type=AppointmentType.Online});
        Add(start.AddMinutes(-15), start.AddMinutes(15));
        Add(start.AddMinutes(15), start.AddMinutes(75), AppointmentStatus.Accepted);
        Add(end.AddMinutes(-75), end.AddMinutes(-15));
        Add(end.AddMinutes(-15), end.AddMinutes(15));
        Add(start.AddHours(-1), start); // Ends on excluded lower boundary.
        Add(end, end.AddHours(1)); // Starts on excluded upper boundary.
        foreach(var status in new[] {AppointmentStatus.Cancelled,AppointmentStatus.Rejected,AppointmentStatus.Completed})
            Add(start.AddHours(6),start.AddHours(7),status);
        await db.SaveChangesAsync();
        var occupied = await service.GetOccupiedSlotsAsync(therapist.Id,date);
        Assert.Equal(4,occupied.Count);
        Assert.Contains(await service.GetOccupiedSlotsAsync(therapist.Id,date.AddDays(-1)), x=>x.StartUtc==start.AddMinutes(-15));
        Assert.Contains(await service.GetOccupiedSlotsAsync(therapist.Id,date.AddDays(1)), x=>x.StartUtc==end.AddMinutes(-15));
    }

    [Fact]
    public async Task Booking_UsesAllDailyIntervalsAndRejectsOvernightWhileKeepingDstRealDuration()
    {
        using var scope=factory.Services.CreateScope();
        var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var service=scope.ServiceProvider.GetRequiredService<IAppointmentService>();
        var client=new Client {User=User()}; var therapist=Therapist();
        db.AddRange(client,therapist); await db.SaveChangesAsync();
        foreach(var (day,start,end) in new[] {(DayOfWeek.Monday,9,12),(DayOfWeek.Monday,14,17),(DayOfWeek.Sunday,0,6),(DayOfWeek.Sunday,22,23)})
            db.TherapistAvailabilities.Add(new() {TherapistId=therapist.Id,DayOfWeek=day,StartTime=TimeSpan.FromHours(start),EndTime=TimeSpan.FromHours(end)});
        await db.SaveChangesAsync();
        CreateAppointmentDto Request(DateTime utc)=>new() {TherapistId=therapist.Id,StartUtc=utc,EndUtc=utc.AddHours(1),Type=AppointmentType.Online};
        // 14:00 Sarajevo lies in the second interval, not the morning interval.
        await service.CreateAsync(client.UserId,Request(new DateTime(2026,7,6,12,0,0,DateTimeKind.Utc)));
        // Spring: 01:00 -> 03:00 wall time is still exactly one real hour.
        var spring=await service.CreateAsync(client.UserId,Request(new DateTime(2026,3,29,0,0,0,DateTimeKind.Utc)));
        Assert.Equal(TimeSpan.FromHours(1),spring.EndUtc-spring.StartUtc);
        await Assert.ThrowsAsync<BadRequestException>(()=>service.CreateAsync(client.UserId,
            Request(new DateTime(2026,10,25,0,0,0,DateTimeKind.Utc))));
        // 23:30 Sunday -> 00:30 Monday cannot wrap into an ordinary daily interval.
        await Assert.ThrowsAsync<BusinessException>(()=>service.CreateAsync(client.UserId,
            Request(new DateTime(2026,7,5,21,30,0,DateTimeKind.Utc))));
    }

    private static ApplicationUser User() => new() {UserName=$"zone-{Guid.NewGuid():N}",FirstName="Time",LastName="Test",IsActive=true};
    private static Therapist Therapist() => new() {User=User(),Biography="Test",Specialization="Test",
        VerificationStatus=TherapistVerificationStatus.Approved,HourlyRate=50};
}
