using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Validators;
using MindBloom.Infrastructure.Time;

namespace MindBloom.UnitTests.Appointments;

public sealed class AppointmentTimeZoneTests
{
    [Theory]
    [InlineData("2026-07-06T07:00:00Z", 9)]
    [InlineData("2026-07-06T15:00:00Z", 17)]
    [InlineData("2026-01-05T08:00:00Z", 9)]
    [InlineData("2026-01-05T16:00:00Z", 17)]
    [InlineData("2026-07-05T22:15:00Z", 0)]
    [InlineData("2026-03-29T00:30:00Z", 1)]
    [InlineData("2026-03-29T01:30:00Z", 3)]
    [InlineData("2026-10-25T00:30:00Z", 2)]
    [InlineData("2026-10-25T01:30:00Z", 2)]
    public void UtcConvertsUsingSarajevoRules(string utc, int hour)
    {
        var local = AppointmentTimeZone.ToLocal(DateTime.Parse(utc).ToUniversalTime());
        Assert.Equal(hour, local.Hour);
    }

    [Theory]
    [InlineData(3, 29, 23, "2026-03-28T23:00:00Z", "2026-03-29T22:00:00Z")]
    [InlineData(10, 25, 25, "2026-10-24T22:00:00Z", "2026-10-25T23:00:00Z")]
    [InlineData(7, 6, 24, "2026-07-05T22:00:00Z", "2026-07-06T22:00:00Z")]
    public void LocalDayHasIndependentUtcBoundaries(int month, int day, int hours, string start, string end)
    {
        var bounds = AppointmentTimeZone.DayBounds(new DateTime(2026, month, day));
        Assert.Equal(DateTime.Parse(start).ToUniversalTime(), bounds.StartUtc);
        Assert.Equal(DateTime.Parse(end).ToUniversalTime(), bounds.EndUtc);
        Assert.Equal(hours, (bounds.EndUtc - bounds.StartUtc).TotalHours);
    }

    [Fact]
    public void SpringGapAndAutumnRepeatedHourAreRecognized()
    {
        Assert.True(AppointmentTimeZone.Zone.IsInvalidTime(new DateTime(2026, 3, 29, 2, 30, 0)));
        Assert.True(AppointmentTimeZone.Zone.IsAmbiguousTime(new DateTime(2026, 10, 25, 2, 30, 0)));
        foreach (var hour in new[] {0, 1})
        {
            var start = new DateTime(2026, 10, 25, hour, 30, 0, DateTimeKind.Utc);
            Assert.Throws<BadRequestException>(() => AppointmentTimeZone.LocalInterval(start, start.AddHours(1)));
        }
    }

    [Theory]
    [InlineData(DateTimeKind.Local)]
    [InlineData(DateTimeKind.Unspecified)]
    public void NonUtcInputIsRejectedWithoutGuessingDeviceZone(DateTimeKind kind)
    {
        var start = DateTime.SpecifyKind(DateTime.UtcNow.AddDays(5), kind);
        Assert.Throws<BadRequestException>(() => AppointmentTimeZone.LocalInterval(start, start.AddHours(1)));
        var result = new CreateAppointmentDtoValidator().Validate(new CreateAppointmentDto
            {TherapistId = 1, StartUtc = start, EndUtc = start.AddHours(1)});
        Assert.Contains(result.Errors, x => x.PropertyName == "StartUtc");
        Assert.Contains(result.Errors, x => x.PropertyName == "EndUtc");
    }

    [Fact]
    public void SpringTransitionKeepsOneRealHour()
    {
        var start = new DateTime(2026, 3, 29, 0, 0, 0, DateTimeKind.Utc);
        var local = AppointmentTimeZone.LocalInterval(start, start.AddHours(1));
        Assert.Equal(1, local.Start.Hour);
        Assert.Equal(3, local.End.Hour);
    }
}
