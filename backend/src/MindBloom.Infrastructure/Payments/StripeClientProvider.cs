using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Exceptions;
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

    private readonly Lazy<IStripeClient> _client;

    // Resolving non-payment services must not initialize an external client.
    public IStripeClient Client => _client.Value;

    public StripeClientProvider(
        IHttpClientFactory httpClientFactory,
        IOptions<StripeSettings> stripeSettings,
        IOptions<ExternalServiceResilienceOptions>
            resilienceOptions,
        ILogger<StripeClientProvider> logger,
        IOptions<ExternalServicesOptions>? externalServices = null)
    {
        var paymentsEnabled = externalServices?.Value.PaymentsEnabled ?? true;
        var secretKey = stripeSettings.Value.SecretKey;
        var options = resilienceOptions.Value;

        // Keep enabled-mode configuration failures; never silently disable payments.
        if (paymentsEnabled && string.IsNullOrWhiteSpace(secretKey))
        {
            throw new InvalidOperationException("Stripe secret key is not configured.");
        }

        _client = new Lazy<IStripeClient>(() =>
        {
            if (!paymentsEnabled)
            {
                throw new BusinessException("Payments are disabled.");
            }

            var httpClient = httpClientFactory.CreateClient("Stripe");
            StripeConfiguration.MaxNetworkRetries = options.StripeMaxNetworkRetries;
            var client = new StripeClient(secretKey,
                httpClient: new SystemNetHttpClient(httpClient));

            logger.LogInformation(StripeClientConfiguredEvent,
                "Stripe client configured. Module: {Module}, TimeoutSeconds: {TimeoutSeconds}, MaxNetworkRetries: {MaxNetworkRetries}.",
                "Payments", options.StripeTimeoutSeconds, options.StripeMaxNetworkRetries);
            return client;
        });
    }
}
