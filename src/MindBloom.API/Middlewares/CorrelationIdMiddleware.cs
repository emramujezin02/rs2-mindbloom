using System.Diagnostics;


namespace MindBloom.API.Middlewares;

public sealed partial class CorrelationIdMiddleware
{
    public const string HeaderName =
        "X-Correlation-ID";

    private const int MaximumCorrelationIdLength =
        100;

    private static readonly EventId
        RequestStartedEvent =
            new(
                1000,
                "RequestStarted");

    private static readonly EventId
        RequestCompletedEvent =
            new(
                1001,
                "RequestCompleted");

    private readonly RequestDelegate _next;

    private readonly ILogger<CorrelationIdMiddleware>
        _logger;

    private readonly IHostEnvironment
        _environment;

    public CorrelationIdMiddleware(
        RequestDelegate next,
        ILogger<CorrelationIdMiddleware> logger,
        IHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(
        HttpContext context)
    {
        var correlationId =
            ResolveCorrelationId(context);

        context.TraceIdentifier =
            correlationId;

        Activity.Current?.SetTag(
            "correlation.id",
            correlationId);

        context.Response.OnStarting(
            () =>
            {
                context.Response.Headers[
                    HeaderName] =
                    correlationId;

                return Task.CompletedTask;
            });

        using var scope =
            _logger.BeginScope(
                new Dictionary<string, object?>
                {
                    ["CorrelationId"] =
                        correlationId,

                    ["RequestPath"] =
                        context.Request.Path.Value
                        ?? string.Empty,

                    ["RequestMethod"] =
                        context.Request.Method,

                    ["Module"] =
                        "API",

                    ["Environment"] =
                        _environment
                            .EnvironmentName
                });

        _logger.LogInformation(
            RequestStartedEvent,
            "HTTP request started. "
            + "Method: {RequestMethod}, "
            + "Path: {RequestPath}.",
            context.Request.Method,
            context.Request.Path.Value);

        await _next(context);

        _logger.LogInformation(
            RequestCompletedEvent,
            "HTTP request completed. "
            + "Method: {RequestMethod}, "
            + "Path: {RequestPath}, "
            + "StatusCode: {StatusCode}.",
            context.Request.Method,
            context.Request.Path.Value,
            context.Response.StatusCode);
    }

    private static string ResolveCorrelationId(
        HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(
                HeaderName,
                out var headerValues) &&
            headerValues.Count == 1)
        {
            var providedCorrelationId =
                headerValues[0]
                    ?.Trim();

            if (TryNormalizeCorrelationId(
                    providedCorrelationId,
                    out var normalizedCorrelationId))
            {
                return normalizedCorrelationId;
            }
        }

        return Guid.NewGuid()
            .ToString("D");
    }

    private static bool
        TryNormalizeCorrelationId(
            string? correlationId,
            out string normalizedCorrelationId)
    {
        normalizedCorrelationId =
            string.Empty;

        if (string.IsNullOrWhiteSpace(
                correlationId))
        {
            return false;
        }

        if (correlationId.Length >
            MaximumCorrelationIdLength)
        {
            return false;
        }

        if (!Guid.TryParse(
                correlationId,
                out var parsedCorrelationId) ||
            parsedCorrelationId ==
                Guid.Empty)
        {
            return false;
        }

        normalizedCorrelationId =
            parsedCorrelationId
                .ToString("D");

        return true;
    }
}