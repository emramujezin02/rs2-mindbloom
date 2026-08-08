using System.Net;
using System.Text;
using MindBloom.SecurityTests.Infrastructure;
using Xunit;

namespace MindBloom.SecurityTests.Stripe;

public sealed class StripeWebhookSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public StripeWebhookSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        StripeWebhook_WithoutSignature_Returns400()
    {
        using var client =
            _factory.CreateClient();

        const string payload =
            """
            {
              "id": "evt_fake_security_test",
              "object": "event",
              "type": "payment_intent.succeeded"
            }
            """;

        using var content =
            new StringContent(
                payload,
                Encoding.UTF8,
                "application/json");

        var response =
            await client.PostAsync(
                "/api/stripe/webhook",
                content);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            response.StatusCode);
    }

    [Fact]
    public async Task
        StripeWebhook_WithFakeSignature_Returns400()
    {
        using var client =
            _factory.CreateClient();

        const string payload =
            """
            {
              "id": "evt_fake_security_test",
              "object": "event",
              "type": "payment_intent.succeeded"
            }
            """;

        using var request =
            new HttpRequestMessage(
                HttpMethod.Post,
                "/api/stripe/webhook");

        request.Content =
            new StringContent(
                payload,
                Encoding.UTF8,
                "application/json");

        request.Headers.TryAddWithoutValidation(
            "Stripe-Signature",
            "t=1234567890,v1=this-is-not-a-valid-stripe-signature");

        var response =
            await client.SendAsync(
                request);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            response.StatusCode);
    }

    [Fact]
    public async Task
        StripeWebhook_WithMalformedSignature_Returns400()
    {
        using var client =
            _factory.CreateClient();

        const string payload =
            """
            {
              "id": "evt_invalid_signature_format",
              "object": "event"
            }
            """;

        using var request =
            new HttpRequestMessage(
                HttpMethod.Post,
                "/api/stripe/webhook");

        request.Content =
            new StringContent(
                payload,
                Encoding.UTF8,
                "application/json");

        request.Headers.TryAddWithoutValidation(
            "Stripe-Signature",
            "definitely-not-a-stripe-signature");

        var response =
            await client.SendAsync(
                request);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            response.StatusCode);
    }
}