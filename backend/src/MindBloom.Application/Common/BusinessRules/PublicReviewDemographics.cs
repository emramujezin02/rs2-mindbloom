namespace MindBloom.Application.Common.BusinessRules;

public static class PublicReviewDemographics
{
    public static int? CalculateAge(DateTime? birthDate, DateTime today)
    {
        today = today.Date;
        if (!birthDate.HasValue || birthDate.Value == default || birthDate.Value.Date > today)
            return null;
        var born = birthDate.Value.Date;
        var age = today.Year - born.Year;
        // A 29 February birthday is reached on 1 March in a non-leap year.
        if (today.Month < born.Month || (today.Month == born.Month && today.Day < born.Day)) age--;
        return age is >= 0 and <= 120 ? age : null;
    }

    public static string? NormalizeGender(string? value) => value?.Trim().ToLowerInvariant() switch
    {
        "male" => "Male",
        "female" => "Female",
        "other" => "Other",
        _ => null
    };
}
