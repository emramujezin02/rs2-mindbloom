using Stripe;

namespace MindBloom.Infrastructure.Payments;

public class StripeVerificationService
{
    private readonly StripeClientProvider _stripeClientProvider;

    public StripeVerificationService(
        StripeClientProvider
            stripeClientProvider)
    {
        _stripeClientProvider = stripeClientProvider;
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

        return await new PaymentIntentService(_stripeClientProvider.Client)
            .GetAsync(
                paymentIntentId,
                cancellationToken:
                    cancellationToken);
    }
}
