using System.Text;
using RabbitMQ.Client;

namespace MindBloom.NotificationsWorker.Messaging;

public static class RabbitMqMessageHelper
{
    private const int MaximumFailureReasonLength =
        500;

    public static int GetRetryCount(
        IDictionary<string, object?>?
            headers)
    {
        if (headers is null ||
            !headers.TryGetValue(
                RabbitMqHeaders.RetryCount,
                out var value) ||
            value is null)
        {
            return 0;
        }

        return value switch
        {
            byte byteValue =>
                byteValue,

            short shortValue =>
                shortValue,

            int intValue =>
                intValue,

            long longValue
                when longValue <=
                     int.MaxValue =>
                (int)longValue,

            byte[] bytes
                when int.TryParse(
                    Encoding.UTF8
                        .GetString(bytes),
                    out var parsedValue) =>
                parsedValue,

            string stringValue
                when int.TryParse(
                    stringValue,
                    out var parsedValue) =>
                parsedValue,

            _ =>
                0
        };
    }

    public static BasicProperties
        CreateForwardProperties(
            IReadOnlyBasicProperties
                originalProperties,
            int retryCount,
            string failureReason,
            string originalQueue)
    {
        ArgumentNullException.ThrowIfNull(
            originalProperties);

        if (retryCount < 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(retryCount),
                "Retry count cannot be negative.");
        }

        if (string.IsNullOrWhiteSpace(
                originalQueue))
        {
            throw new ArgumentException(
                "Original RabbitMQ queue is required.",
                nameof(originalQueue));
        }

        var headers =
            CloneHeaders(
                originalProperties.Headers);

        headers[
            RabbitMqHeaders.RetryCount] =
                retryCount;

        headers[
            RabbitMqHeaders
                .LastFailureReason] =
                Truncate(
                    failureReason,
                    MaximumFailureReasonLength);

        headers[
            RabbitMqHeaders
                .LastFailureAtUtc] =
                DateTime.UtcNow
                    .ToString("O");

        headers[
            RabbitMqHeaders
                .OriginalQueue] =
                originalQueue;

        return new BasicProperties
        {
            Persistent =
                true,

            ContentType =
                originalProperties.ContentType
                ?? "application/json",

            ContentEncoding =
                originalProperties
                    .ContentEncoding
                ?? "utf-8",

            MessageId =
                originalProperties.MessageId,

            CorrelationId =
                originalProperties
                    .CorrelationId,

            Type =
                originalProperties.Type,

            AppId =
                originalProperties.AppId
                ?? "MindBloom.NotificationsWorker",

            Timestamp =
                originalProperties.Timestamp,

            Headers =
                headers
        };
    }

    public static string Truncate(
        string? value,
        int maximumLength =
            MaximumFailureReasonLength)
    {
        if (string.IsNullOrEmpty(
                value))
        {
            return string.Empty;
        }

        if (maximumLength <= 0)
        {
            return string.Empty;
        }

        return value.Length <=
               maximumLength
            ? value
            : value[
                ..maximumLength];
    }

    private static Dictionary<
        string,
        object?> CloneHeaders(
        IDictionary<string, object?>?
            originalHeaders)
    {
        if (originalHeaders is null)
        {
            return new Dictionary<
                string,
                object?>();
        }

        return originalHeaders
            .ToDictionary(
                item =>
                    item.Key,
                item =>
                    item.Value);
    }
}