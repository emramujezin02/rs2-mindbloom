namespace MindBloom.Infrastructure.Options;

public sealed class GoogleMapOptions
{
    public string ApiKey { get; set; } =
        string.Empty;

    public string BaseUrl { get; set; } =
        "https://maps.googleapis.com/maps/api";
}