using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Security;
using Stripe;

namespace MindBloom.Infrastructure.Payments;

public sealed class StripeClientProvider
{
    private static readonly EventId
        StripeClientConfiguredEvent =
            new(
                5100,
                "StripeClientConfigured");

    public IStripeClient Client
    {
        get;
    }

    public StripeClientProvider(
        IHttpClientFactory httpClientFactory,
        IOptions<StripeSettings> stripeSettings,
        IOptions<ExternalServiceResilienceOptions>
            resilienceOptions,
        ILogger<StripeClientProvider> logger)
    {
        var settings =
            stripeSettings.Value;

        var options =
            resilienceOptions.Value;

        if (string.IsNullOrWhiteSpace(
                settings.SecretKey))
        {
            throw new InvalidOperationException(
                "Stripe secret key is not configured.");
        }

        var httpClient =
            httpClientFactory.CreateClient(
                "Stripe");

        StripeConfiguration.MaxNetworkRetries =
            options.StripeMaxNetworkRetries;

        Client =
            new StripeClient(
                settings.SecretKey,
                httpClient:
                    new SystemNetHttpClient(
                        httpClient));

        logger.LogInformation(
            StripeClientConfiguredEvent,
            "Stripe client configured. Module: {Module}, TimeoutSeconds: {TimeoutSeconds}, MaxNetworkRetries: {MaxNetworkRetries}.",
            "Payments",
            options.StripeTimeoutSeconds,
            options.StripeMaxNetworkRetries);
    }
}