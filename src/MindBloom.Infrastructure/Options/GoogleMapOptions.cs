using MindBloom.Application.Common.Models;

namespace MindBloom.Application.Common.Interfaces;

public interface IGeocodingService
{
    Task<GeocodingResult> GeocodeAddressAsync(
        string country,
        string city,
        string? address,
        CancellationToken cancellationToken = default);
}