using System.Collections.Concurrent;
using System.Net;
using System.Text;
using System.Text.Json;

namespace MindBloom.IntegrationTests.EndToEnd.Infrastructure;

public sealed class FakeStripeHttpMessageHandler
    : HttpMessageHandler
{
    private static readonly ConcurrentDictionary<
        string,
        FakePaymentIntent>
        PaymentIntents =
            new();

    protected override async Task<HttpResponseMessage>
        SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
    {
        cancellationToken
            .ThrowIfCancellationRequested();

        var path =
            request.RequestUri?
                .AbsolutePath
            ?? string.Empty;

        if (request.Method ==
                HttpMethod.Post &&
            string.Equals(
                path,
                "/v1/payment_intents",
                StringComparison.OrdinalIgnoreCase))
        {
            return await CreatePaymentIntentAsync(
                request,
                cancellationToken);
        }

        if (request.Method ==
                HttpMethod.Get &&
            path.StartsWith(
                "/v1/payment_intents/",
                StringComparison.OrdinalIgnoreCase))
        {
            var paymentIntentId =
                path[
                    "/v1/payment_intents/"
                        .Length..];

            return GetPaymentIntent(
                paymentIntentId);
        }

        return CreateJsonResponse(
            HttpStatusCode.NotFound,
            new
            {
                error =
                    new
                    {
                        message =
                            $"Unsupported fake Stripe endpoint: "
                            + $"{request.Method} {path}"
                    }
            });
    }

    private static async Task<HttpResponseMessage>
        CreatePaymentIntentAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
    {
        var body =
            request.Content == null
                ? string.Empty
                : await request.Content
                    .ReadAsStringAsync(
                        cancellationToken);

        var form =
            ParseForm(body);

        var amount =
            GetLong(
                form,
                "amount");

        var currency =
            GetValue(
                form,
                "currency")
            ?? "usd";

        var description =
            GetValue(
                form,
                "description");

        var appointmentId =
            GetValue(
                form,
                "metadata[appointmentId]")
            ?? string.Empty;

        var clientUserId =
            GetValue(
                form,
                "metadata[clientUserId]")
            ?? string.Empty;

        var clientId =
            GetValue(
                form,
                "metadata[clientId]")
            ?? string.Empty;

        var id =
            $"pi_e2e_{Guid.NewGuid():N}";

        var paymentIntent =
            new FakePaymentIntent
            {
                Id =
                    id,

                Amount =
                    amount,

                Currency =
                    currency,

                Status =
                    "succeeded",

                ClientSecret =
                    $"{id}_secret_e2e",

                Description =
                    description,

                AppointmentId =
                    appointmentId,

                ClientUserId =
                    clientUserId,

                ClientId =
                    clientId
            };

        PaymentIntents[id] =
            paymentIntent;

        return CreatePaymentIntentResponse(
            paymentIntent);
    }

    private static HttpResponseMessage
        GetPaymentIntent(
            string paymentIntentId)
    {
        if (!PaymentIntents.TryGetValue(
                paymentIntentId,
                out var paymentIntent))
        {
            return CreateJsonResponse(
                HttpStatusCode.NotFound,
                new
                {
                    error =
                        new
                        {
                            message =
                                "Fake Stripe PaymentIntent "
                                + "was not found."
                        }
                });
        }

        return CreatePaymentIntentResponse(
            paymentIntent);
    }

    private static HttpResponseMessage
        CreatePaymentIntentResponse(
            FakePaymentIntent paymentIntent)
    {
        var created =
            DateTimeOffset.UtcNow
                .ToUnixTimeSeconds();

        return CreateJsonResponse(
            HttpStatusCode.OK,
            new
            {
                id =
                    paymentIntent.Id,

                @object =
                    "payment_intent",

                amount =
                    paymentIntent.Amount,

                amount_received =
                    paymentIntent.Amount,

                amount_capturable =
                    0,

                currency =
                    paymentIntent.Currency,

                status =
                    paymentIntent.Status,

                client_secret =
                    paymentIntent.ClientSecret,

                description =
                    paymentIntent.Description,

                livemode =
                    false,

                created,

                metadata =
                    new Dictionary<
                        string,
                        string>
                    {
                        ["appointmentId"] =
                            paymentIntent
                                .AppointmentId,

                        ["clientUserId"] =
                            paymentIntent
                                .ClientUserId,

                        ["clientId"] =
                            paymentIntent
                                .ClientId
                    },

                payment_method_types =
                    new[]
                    {
                        "card"
                    }
            });
    }

    private static Dictionary<string, string>
        ParseForm(
            string value)
    {
        var result =
            new Dictionary<
                string,
                string>(
                StringComparer.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(
                value))
        {
            return result;
        }

        foreach (var item in value.Split(
                     '&',
                     StringSplitOptions
                         .RemoveEmptyEntries))
        {
            var parts =
                item.Split(
                    '=',
                    2);

            var key =
                Uri.UnescapeDataString(
                    parts[0]
                        .Replace(
                            "+",
                            " "));

            var formValue =
                parts.Length > 1
                    ? Uri.UnescapeDataString(
                        parts[1]
                            .Replace(
                                "+",
                                " "))
                    : string.Empty;

            result[key] =
                formValue;
        }

        return result;
    }

    private static string?
        GetValue(
            IReadOnlyDictionary<
                string,
                string> form,
            string key)
    {
        return form.TryGetValue(
            key,
            out var value)
                ? value
                : null;
    }

    private static long GetLong(
        IReadOnlyDictionary<
            string,
            string> form,
        string key)
    {
        var value =
            GetValue(
                form,
                key);

        return long.TryParse(
            value,
            out var result)
                ? result
                : 0;
    }

    private static HttpResponseMessage
        CreateJsonResponse(
            HttpStatusCode statusCode,
            object body)
    {
        var json =
            JsonSerializer.Serialize(
                body,
                new JsonSerializerOptions(
                    JsonSerializerDefaults.Web));

        return new HttpResponseMessage(
            statusCode)
        {
            Content =
                new StringContent(
                    json,
                    Encoding.UTF8,
                    "application/json")
        };
    }

    private sealed class FakePaymentIntent
    {
        public string Id { get; init; } =
            string.Empty;

        public long Amount { get; init; }

        public string Currency { get; init; } =
            "usd";

        public string Status { get; init; } =
            "succeeded";

        public string ClientSecret { get; init; } =
            string.Empty;

        public string? Description { get; init; }

        public string AppointmentId
        {
            get;
            init;
        } = string.Empty;

        public string ClientUserId
        {
            get;
            init;
        } = string.Empty;

        public string ClientId
        {
            get;
            init;
        } = string.Empty;
    }
}