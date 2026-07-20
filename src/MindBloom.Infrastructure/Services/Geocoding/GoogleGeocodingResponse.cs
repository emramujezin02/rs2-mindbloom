using System.Text.Json.Serialization;

namespace MindBloom.Infrastructure.Services.Geocoding;

internal sealed class GoogleGeocodingResponse
{
    [JsonPropertyName("results")]
    public List<GoogleGeocodingResultItem> Results { get; set; } = [];

    [JsonPropertyName("status")]
    public string Status { get; set; } = string.Empty;

    [JsonPropertyName("error_message")]
    public string? ErrorMessage { get; set; }
}

internal sealed class GoogleGeocodingResultItem
{
    [JsonPropertyName("formatted_address")]
    public string? FormattedAddress { get; set; }

    [JsonPropertyName("geometry")]
    public GoogleGeocodingGeometry Geometry { get; set; } = new();
}

internal sealed class GoogleGeocodingGeometry
{
    [JsonPropertyName("location")]
    public GoogleGeocodingLocation Location { get; set; } = new();
}

internal sealed class GoogleGeocodingLocation
{
    [JsonPropertyName("lat")]
    public double Latitude { get; set; }

    [JsonPropertyName("lng")]
    public double Longitude { get; set; }
}