using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Models;

namespace MindBloom.Infrastructure.Services.Geocoding;

public sealed class TestGeocodingService
    : IGeocodingService
{
    public Task<GeocodingResult>
        GeocodeAddressAsync(
            string country,
            string city,
            string? address,
            CancellationToken cancellationToken =
                default)
    {
        cancellationToken
            .ThrowIfCancellationRequested();

        var parts =
            new[]
            {
                address,
                city,
                country
            }
            .Where(value =>
                !string.IsNullOrWhiteSpace(
                    value))
            .Select(value =>
                value!.Trim());

        var formattedAddress =
            string.Join(
                ", ",
                parts);

        var result =
            GeocodingResult.Success(
                latitude: 43.8563,
                longitude: 18.4131,
                formattedAddress:
                    string.IsNullOrWhiteSpace(
                        formattedAddress)
                        ? "MindBloom test location"
                        : formattedAddress);

        return Task.FromResult(
            result);
    }
}