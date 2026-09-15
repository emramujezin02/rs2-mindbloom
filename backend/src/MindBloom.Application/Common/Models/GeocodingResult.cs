namespace MindBloom.Application.Common.Models;

public sealed class GeocodingResult
{
    public bool IsSuccessful { get; init; }

    public double? Latitude { get; init; }

    public double? Longitude { get; init; }

    public string? FormattedAddress { get; init; }

    public string? ErrorMessage { get; init; }

    public static GeocodingResult Success(
        double latitude,
        double longitude,
        string? formattedAddress)
    {
        return new GeocodingResult
        {
            IsSuccessful = true,
            Latitude = latitude,
            Longitude = longitude,
            FormattedAddress = formattedAddress
        };
    }

    public static GeocodingResult Failure(string errorMessage)
    {
        return new GeocodingResult
        {
            IsSuccessful = false,
            ErrorMessage = errorMessage
        };
    }
}