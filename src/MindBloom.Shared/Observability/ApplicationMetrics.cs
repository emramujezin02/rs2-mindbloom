using System.Collections.Concurrent;
using System.Threading;

namespace MindBloom.Shared.Observability;

public sealed class ApplicationMetrics
{
    private long _requestCount;

    private long _requestDurationMilliseconds;

    private long _clientErrorCount;

    private long _serverErrorCount;

    private long _activeSignalRConnections;

    private long _rabbitMqPublishedCount;

    private long _rabbitMqConsumedCount;

    private long _rabbitMqDlqMovedCount;

    private long _paymentSuccessCount;

    private long _paymentFailureCount;

    private long _appointmentCreatedCount;

    private long _notificationSentCount;

    private long _emailDlqDepth;

    private long _integrationEventDlqDepth;

    private readonly ConcurrentDictionary<
        string,
        long>
        _retryCounts =
            new(
                StringComparer.Ordinal);

    private readonly ConcurrentDictionary<
        string,
        HttpRouteMetrics>
        _httpRoutes =
            new(
                StringComparer.Ordinal);

    public void RecordRequest(
        string method,
        string routeTemplate,
        int statusCode,
        long durationMilliseconds)
    {
        Interlocked.Increment(
            ref _requestCount);

        Interlocked.Add(
            ref _requestDurationMilliseconds,
            Math.Max(
                0,
                durationMilliseconds));

        if (statusCode is >= 400 and <= 499)
        {
            Interlocked.Increment(
                ref _clientErrorCount);
        }

        if (statusCode >= 500)
        {
            Interlocked.Increment(
                ref _serverErrorCount);
        }

        var normalizedMethod =
            string.IsNullOrWhiteSpace(method)
                ? "UNKNOWN"
                : method
                    .Trim()
                    .ToUpperInvariant();

        /*
         * IMPORTANT:
         * routeTemplate mora biti route pattern,
         * npr. /api/appointments/{id},
         * nikada raw URL sa konkretnim ID-em.
         */
        var normalizedRoute =
            string.IsNullOrWhiteSpace(
                routeTemplate)
                ? "unmatched"
                : routeTemplate.Trim();

        var routeKey =
            $"{normalizedMethod} "
            + normalizedRoute;

        var routeMetrics =
            _httpRoutes.GetOrAdd(
                routeKey,
                _ =>
                    new HttpRouteMetrics());

        routeMetrics.Record(
            statusCode,
            durationMilliseconds);
    }

    public void IncrementSignalRConnections()
    {
        Interlocked.Increment(
            ref _activeSignalRConnections);
    }

    public void DecrementSignalRConnections()
    {
        while (true)
        {
            var current =
                Interlocked.Read(
                    ref _activeSignalRConnections);

            if (current <= 0)
            {
                return;
            }

            if (Interlocked.CompareExchange(
                    ref _activeSignalRConnections,
                    current - 1,
                    current) ==
                current)
            {
                return;
            }
        }
    }

    public void RecordRabbitMqPublished()
    {
        Interlocked.Increment(
            ref _rabbitMqPublishedCount);
    }

    public void RecordRabbitMqConsumed()
    {
        Interlocked.Increment(
            ref _rabbitMqConsumedCount);
    }

    public void RecordRetry(
        string component)
    {
        var normalizedComponent =
            NormalizeComponent(
                component);

        _retryCounts.AddOrUpdate(
            normalizedComponent,
            1,
            (_, current) =>
                current + 1);
    }

    public void RecordDlqMoved()
    {
        Interlocked.Increment(
            ref _rabbitMqDlqMovedCount);
    }

    public void SetDlqDepth(
        string queueType,
        long messageCount)
    {
        var safeCount =
            Math.Max(
                0,
                messageCount);

        if (string.Equals(
                queueType,
                "Email",
                StringComparison.OrdinalIgnoreCase))
        {
            Interlocked.Exchange(
                ref _emailDlqDepth,
                safeCount);

            return;
        }

        if (string.Equals(
                queueType,
                "IntegrationEvent",
                StringComparison.OrdinalIgnoreCase))
        {
            Interlocked.Exchange(
                ref _integrationEventDlqDepth,
                safeCount);
        }
    }

    public void RecordPaymentSuccess()
    {
        Interlocked.Increment(
            ref _paymentSuccessCount);
    }

    public void RecordPaymentFailure()
    {
        Interlocked.Increment(
            ref _paymentFailureCount);
    }

    public void RecordAppointmentCreated()
    {
        Interlocked.Increment(
            ref _appointmentCreatedCount);
    }

    public void RecordNotificationSent()
    {
        Interlocked.Increment(
            ref _notificationSentCount);
    }

    public ApplicationMetricsSnapshot
        GetSnapshot()
    {
        var requestCount =
            Interlocked.Read(
                ref _requestCount);

        var totalDuration =
            Interlocked.Read(
                ref _requestDurationMilliseconds);

        var averageDuration =
            requestCount == 0
                ? 0
                : Math.Round(
                    totalDuration /
                    (double)requestCount,
                    2);

        var routeMetrics =
            _httpRoutes
                .OrderBy(item =>
                    item.Key,
                    StringComparer.Ordinal)
                .ToDictionary(
                    item =>
                        item.Key,
                    item =>
                        item.Value.GetSnapshot(),
                    StringComparer.Ordinal);

        var retries =
            _retryCounts
                .OrderBy(item =>
                    item.Key,
                    StringComparer.Ordinal)
                .ToDictionary(
                    item =>
                        item.Key,
                    item =>
                        item.Value,
                    StringComparer.Ordinal);

        return new ApplicationMetricsSnapshot
        {
            Http =
                new HttpMetricsSnapshot
                {
                    RequestCount =
                        requestCount,

                    AverageDurationMilliseconds =
                        averageDuration,

                    TotalDurationMilliseconds =
                        totalDuration,

                    ClientError4xxCount =
                        Interlocked.Read(
                            ref _clientErrorCount),

                    ServerError5xxCount =
                        Interlocked.Read(
                            ref _serverErrorCount),

                    Routes =
                        routeMetrics
                },

            SignalR =
                new SignalRMetricsSnapshot
                {
                    ActiveConnections =
                        Interlocked.Read(
                            ref _activeSignalRConnections)
                },

            RabbitMq =
                new RabbitMqMetricsSnapshot
                {
                    PublishedCount =
                        Interlocked.Read(
                            ref _rabbitMqPublishedCount),

                    ConsumedCount =
                        Interlocked.Read(
                            ref _rabbitMqConsumedCount),

                    DlqMovedCount =
                        Interlocked.Read(
                            ref _rabbitMqDlqMovedCount),

                    EmailDlqDepth =
                        Interlocked.Read(
                            ref _emailDlqDepth),

                    IntegrationEventDlqDepth =
                        Interlocked.Read(
                            ref _integrationEventDlqDepth)
                },

            RetryCounts =
                retries,

            Business =
                new BusinessMetricsSnapshot
                {
                    PaymentSuccessCount =
                        Interlocked.Read(
                            ref _paymentSuccessCount),

                    PaymentFailureCount =
                        Interlocked.Read(
                            ref _paymentFailureCount),

                    AppointmentCreatedCount =
                        Interlocked.Read(
                            ref _appointmentCreatedCount),

                    NotificationSentCount =
                        Interlocked.Read(
                            ref _notificationSentCount)
                }
        };
    }

    private static string NormalizeComponent(
        string component)
    {
        if (string.IsNullOrWhiteSpace(
                component))
        {
            return "unknown";
        }

        return component
            .Trim()
            .ToLowerInvariant();
    }

    private sealed class HttpRouteMetrics
    {
        private long _requestCount;

        private long _durationMilliseconds;

        private long _clientErrorCount;

        private long _serverErrorCount;

        public void Record(
            int statusCode,
            long durationMilliseconds)
        {
            Interlocked.Increment(
                ref _requestCount);

            Interlocked.Add(
                ref _durationMilliseconds,
                Math.Max(
                    0,
                    durationMilliseconds));

            if (statusCode is >= 400 and <= 499)
            {
                Interlocked.Increment(
                    ref _clientErrorCount);
            }

            if (statusCode >= 500)
            {
                Interlocked.Increment(
                    ref _serverErrorCount);
            }
        }

        public HttpRouteMetricSnapshot
            GetSnapshot()
        {
            var requestCount =
                Interlocked.Read(
                    ref _requestCount);

            var totalDuration =
                Interlocked.Read(
                    ref _durationMilliseconds);

            return new HttpRouteMetricSnapshot
            {
                RequestCount =
                    requestCount,

                AverageDurationMilliseconds =
                    requestCount == 0
                        ? 0
                        : Math.Round(
                            totalDuration /
                            (double)requestCount,
                            2),

                ClientError4xxCount =
                    Interlocked.Read(
                        ref _clientErrorCount),

                ServerError5xxCount =
                    Interlocked.Read(
                        ref _serverErrorCount)
            };
        }
    }
}

public sealed class ApplicationMetricsSnapshot
{
    public HttpMetricsSnapshot Http
    {
        get;
        init;
    } = new();

    public SignalRMetricsSnapshot SignalR
    {
        get;
        init;
    } = new();

    public RabbitMqMetricsSnapshot RabbitMq
    {
        get;
        init;
    } = new();

    public IReadOnlyDictionary<string, long>
        RetryCounts
    {
        get;
        init;
    } =
        new Dictionary<string, long>();

    public BusinessMetricsSnapshot Business
    {
        get;
        init;
    } = new();

    public DateTime GeneratedAtUtc
    {
        get;
        init;
    } = DateTime.UtcNow;
}

public sealed class HttpMetricsSnapshot
{
    public long RequestCount { get; init; }

    public long TotalDurationMilliseconds
    {
        get;
        init;
    }

    public double AverageDurationMilliseconds
    {
        get;
        init;
    }

    public long ClientError4xxCount
    {
        get;
        init;
    }

    public long ServerError5xxCount
    {
        get;
        init;
    }

    public IReadOnlyDictionary<
        string,
        HttpRouteMetricSnapshot>
        Routes
    {
        get;
        init;
    } =
        new Dictionary<
            string,
            HttpRouteMetricSnapshot>();
}

public sealed class HttpRouteMetricSnapshot
{
    public long RequestCount { get; init; }

    public double AverageDurationMilliseconds
    {
        get;
        init;
    }

    public long ClientError4xxCount
    {
        get;
        init;
    }

    public long ServerError5xxCount
    {
        get;
        init;
    }
}

public sealed class SignalRMetricsSnapshot
{
    public long ActiveConnections
    {
        get;
        init;
    }
}

public sealed class RabbitMqMetricsSnapshot
{
    public long PublishedCount
    {
        get;
        init;
    }

    public long ConsumedCount
    {
        get;
        init;
    }

    public long DlqMovedCount
    {
        get;
        init;
    }

    public long EmailDlqDepth
    {
        get;
        init;
    }

    public long IntegrationEventDlqDepth
    {
        get;
        init;
    }
}

public sealed class BusinessMetricsSnapshot
{
    public long PaymentSuccessCount
    {
        get;
        init;
    }

    public long PaymentFailureCount
    {
        get;
        init;
    }

    public long AppointmentCreatedCount
    {
        get;
        init;
    }

    public long NotificationSentCount
    {
        get;
        init;
    }
}