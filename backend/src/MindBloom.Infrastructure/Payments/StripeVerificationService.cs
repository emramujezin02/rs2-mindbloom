using Stripe;

namespace MindBloom.Infrastructure.Payments;

public class StripeVerificationService
{
    private readonly PaymentIntentService
        _paymentIntentService;

    public StripeVerificationService(
        StripeClientProvider
            stripeClientProvider)
    {
        _paymentIntentService =
            new PaymentIntentService(
                stripeClientProvider.Client);
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