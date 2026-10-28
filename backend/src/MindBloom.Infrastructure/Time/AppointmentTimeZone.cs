using MindBloom.Application.Common.Exceptions;

namespace MindBloom.Infrastructure.Time;

/// <summary>The recurring therapist schedule uses Sarajevo wall time; appointments use UTC.</summary>
public static class AppointmentTimeZone
{
    public const string IanaId = "Europe/Sarajevo";
    public static TimeZoneInfo Zone { get; } = Resolve();

    private static TimeZoneInfo Resolve()
    {
        if (TimeZoneInfo.TryFindSystemTimeZoneById(IanaId, out var zone)) return zone;
        if (TimeZoneInfo.TryConvertIanaIdToWindowsId(IanaId, out var windowsId))
            return TimeZoneInfo.FindSystemTimeZoneById(windowsId);
        throw new TimeZoneNotFoundException($"Required appointment time zone {IanaId} is unavailable.");
    }

    public static DateTime ToLocal(DateTime utc)
    {
        if (utc.Kind != DateTimeKind.Utc)
            throw new BadRequestException("Appointment start and end times must be UTC (with Z suffix).");
        return TimeZoneInfo.ConvertTimeFromUtc(utc, Zone);
    }

    public static (DateTime Start, DateTime End) LocalInterval(DateTime startUtc, DateTime endUtc)
    {
        var start = ToLocal(startUtc);
        var end = ToLocal(endUtc);
        // A wall-clock-only picker cannot identify which repeated hour was intended.
        if (Zone.IsAmbiguousTime(start) || Zone.IsAmbiguousTime(end))
            throw new BadRequestException("Appointment time is ambiguous during the daylight saving transition. Choose another time.");
        return (start, end);
    }

    public static (DateTime StartUtc, DateTime EndUtc) DayBounds(DateTime localDate)
    {
        var start = DateTime.SpecifyKind(localDate.Date, DateTimeKind.Unspecified);
        return (TimeZoneInfo.ConvertTimeToUtc(start, Zone),
            TimeZoneInfo.ConvertTimeToUtc(start.AddDays(1), Zone));
    }
}
