using System.Globalization;

namespace MindBloom.Infrastructure.Serialization;

public static class ClientPreferenceFormat
{
    // Text lists use pipes; commas remain readable for legacy profiles and seed data.
    private static readonly char[] Separators = ['|', ','];

    public static List<string> SplitTextValues(string? value)
        => string.IsNullOrWhiteSpace(value)
            ? []
            : value.Split(Separators, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Distinct(StringComparer.OrdinalIgnoreCase).ToList();

    public static string? SerializeTextValues(IEnumerable<string>? values)
    {
        var normalized = (values ?? []).SelectMany(SplitTextValues)
            .Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x).ToList();
        return normalized.Count == 0 ? null : string.Join("|", normalized);
    }

    public static List<DayOfWeek> SplitDays(string? value)
    {
        var days = new HashSet<DayOfWeek>();
        foreach (var token in SplitTextValues(value))
        {
            if (int.TryParse(token, NumberStyles.Integer, CultureInfo.InvariantCulture, out var number))
            {
                if (number is >= 0 and <= 6) days.Add((DayOfWeek)number);
            }
            else if (Enum.TryParse<DayOfWeek>(token, true, out var day) && Enum.IsDefined(day))
            {
                days.Add(day);
            }
        }
        return days.OrderBy(x => (int)x).ToList();
    }

    public static string? SerializeDays(IEnumerable<DayOfWeek>? days)
    {
        var normalized = (days ?? []).Where(x => Enum.IsDefined(x)).Distinct().OrderBy(x => (int)x)
            .Select(x => ((int)x).ToString(CultureInfo.InvariantCulture)).ToList();
        return normalized.Count == 0 ? null : string.Join(",", normalized);
    }
}
