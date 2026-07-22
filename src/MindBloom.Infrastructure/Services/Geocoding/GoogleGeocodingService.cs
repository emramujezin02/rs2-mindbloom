using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Common.Models;

namespace MindBloom.Infrastructure.Services.Geocoding;

public sealed class GoogleGeocodingService : IGeocodingService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<GoogleGeocodingService> _logger;

    public GoogleGeocodingService(
        HttpClient httpClient,
        ILogger<GoogleGeocodingService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<GeocodingResult> GeocodeAddressAsync(
        string country,
        string city,
        string? address,
        CancellationToken cancellationToken = default)
    {
        var apiKey =
    Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");

        if (string.IsNullOrWhiteSpace(apiKey))
        {
            _logger.LogWarning(
                "Google Maps API key is not configured. Geocoding was skipped.");

            return GeocodingResult.Failure(
                "Google Maps API key is not configured.");
        }

        var normalizedCountry = country.Trim();
        var normalizedCity = city.Trim();
        var normalizedAddress = address?.Trim() ?? string.Empty;

        var addressParts = new List<string>();

        if (!string.IsNullOrWhiteSpace(normalizedAddress))
        {
            addressParts.Add(normalizedAddress);
        }

        if (!string.IsNullOrWhiteSpace(normalizedCity))
        {
            addressParts.Add(normalizedCity);
        }

        if (!string.IsNullOrWhiteSpace(normalizedCountry))
        {
            addressParts.Add(normalizedCountry);
        }

        if (addressParts.Count == 0)
        {
            return GeocodingResult.Failure(
                "No address information was provided.");
        }

        var fullAddress = string.Join(", ", addressParts);

        var requestUrl =
            $"json?address={Uri.EscapeDataString(fullAddress)}" +
            $"&key={Uri.EscapeDataString(apiKey)}";

        try
        {
            using var response = await _httpClient.GetAsync(
                requestUrl,
                cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Google Geocoding API returned HTTP status {StatusCode}.",
                    response.StatusCode);

                return GeocodingResult.Failure(
                    "Geocoding service is currently unavailable.");
            }

            var geocodingResponse =
                await response.Content.ReadFromJsonAsync<GoogleGeocodingResponse>(
                    cancellationToken: cancellationToken);

            if (geocodingResponse is null)
            {
                return GeocodingResult.Failure(
                    "The geocoding service returned an empty response.");
            }

            if (!string.Equals(
                    geocodingResponse.Status,
                    "OK",
                    StringComparison.OrdinalIgnoreCase))
            {
                var message = string.IsNullOrWhiteSpace(
                    geocodingResponse.ErrorMessage)
                    ? $"Google Geocoding status: {geocodingResponse.Status}."
                    : geocodingResponse.ErrorMessage;

                _logger.LogWarning(
                    "Google Geocoding request failed with status {Status}.",
                    geocodingResponse.Status);

                return GeocodingResult.Failure(message);
            }

            var firstResult = geocodingResponse.Results.FirstOrDefault();

            if (firstResult is null)
            {
                return GeocodingResult.Failure(
                    "The provided address could not be located.");
            }

            return GeocodingResult.Success(
                firstResult.Geometry.Location.Latitude,
                firstResult.Geometry.Location.Longitude,
                firstResult.FormattedAddress);
        }
        catch (OperationCanceledException)
            when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning(
                "Google Geocoding request timed out.");

            return GeocodingResult.Failure(
                "The geocoding request timed out.");
        }
        catch (HttpRequestException exception)
        {
            _logger.LogError(
                exception,
                "Google Geocoding HTTP request failed.");

            return GeocodingResult.Failure(
                "The geocoding service could not be reached.");
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Unexpected geocoding error.");

            return GeocodingResult.Failure(
                "An unexpected geocoding error occurred.");
        }
    }
}