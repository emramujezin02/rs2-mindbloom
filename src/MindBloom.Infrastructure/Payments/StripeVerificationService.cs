using Stripe;

namespace MindBloom.Infrastructure.Payments;

public class StripeVerificationService
{
    private readonly PaymentIntentService
        _paymentIntentService;

    public StripeVerificationService()
    {
        var secretKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SECRET_KEY");

        if (string.IsNullOrWhiteSpace(
                secretKey))
        {
            throw new InvalidOperationException(
                "STRIPE_SECRET_KEY is not configured.");
        }

        StripeConfiguration.ApiKey =
            secretKey;

        _paymentIntentService =
            new PaymentIntentService();
    }

    public async Task<PaymentIntent>
        GetPaymentIntentAsync(
            string paymentIntentId,
            CancellationToken cancellationToken =
                default)
    {
        if (string.IsNullOrWhiteSpace(
                paymentIntentId))
        {
            throw new ArgumentException(
                "Payment intent ID is required.",
                nameof(paymentIntentId));
        }

        return await _paymentIntentService
            .GetAsync(
                paymentIntentId,
                cancellationToken:
                    cancellationToken);
    }
}