using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Security;
using Stripe;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/stripe")]
public sealed class StripeWebhookController
    : ControllerBase
{
    private readonly StripeWebhookService
        _webhookService;

    private readonly StripeSettings
        _stripeSettings;

    private readonly ILogger<
        StripeWebhookController>
        _logger;

    public StripeWebhookController(
        StripeWebhookService webhookService,
        IOptions<StripeSettings> stripeSettings,
        ILogger<StripeWebhookController> logger)
    {
        _webhookService =
            webhookService;

        _stripeSettings =
            stripeSettings.Value;

        _logger =
            logger;
    }

    [AllowAnonymous]
    [HttpPost("webhook")]
    public async Task<IActionResult>
        Webhook(
            CancellationToken cancellationToken)
    {
        /*
         * Stripe requires the original raw
         * request body for signature validation.
         * Do not deserialize into a DTO first.
         */
        string json;

        using (var reader =
               new StreamReader(
                   Request.Body))
        {
            json =
                await reader
                    .ReadToEndAsync();
        }

        var signatureHeader =
            Request.Headers[
                    "Stripe-Signature"]
                .FirstOrDefault();

        if (string.IsNullOrWhiteSpace(
                signatureHeader))
        {
            _logger.LogWarning(
                "Stripe webhook rejected because the signature header is missing.");

            return BadRequest(
                new
                {
                    message =
                        "Invalid webhook request."
                });
        }

        Event stripeEvent;

        try
        {
            /*
             * ConstructEvent performs Stripe's
             * cryptographic signature validation.
             *
             * The secret itself is never logged.
             */
            stripeEvent =
                EventUtility.ConstructEvent(
                    json,
                    signatureHeader,
                    _stripeSettings
                        .WebhookSecret);
        }
        catch (StripeException)
        {
            _logger.LogWarning(
                "Stripe webhook rejected because signature validation failed.");

            return BadRequest(
                new
                {
                    message =
                        "Invalid webhook signature."
                });
        }

        await _webhookService
            .ProcessAsync(
                stripeEvent,
                cancellationToken);

        return Ok(
            new
            {
                received =
                    true
            });
    }
}