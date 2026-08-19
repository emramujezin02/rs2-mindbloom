using System.Diagnostics;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;

namespace MindBloom.API.Middlewares;

public sealed class RequestTimingMiddleware
{
    private static readonly EventId
        RequestTimingEvent =
            new(
                1100,
                "RequestTiming");

    private static readonly EventId
        SlowRequestEvent =
            new(
                1101,
                "SlowRequest");

    private readonly RequestDelegate _next;

    private readonly ILogger<RequestTimingMiddleware>
        _logger;

    private readonly RequestTimingOptions
        _options;

    public RequestTimingMiddleware(
        RequestDelegate next,
        ILogger<RequestTimingMiddleware> logger,
        IOptions<RequestTimingOptions> options)
    {
        _next = next;
        _logger = logger;
        _options = options.Value;
    }

    public async Task InvokeAsync(
        HttpContext context)
    {
        if (IsHealthEndpoint(
                context.Request.Path))
        {
            await _next(context);

            return;
        }

        var stopwatch =
            Stopwatch.StartNew();

        try
        {
            await _next(context);
        }
        finally
        {
            stopwatch.Stop();

            var elapsedMilliseconds =
                stopwatch.ElapsedMilliseconds;

            var routeEndpoint =
                context.GetEndpoint()
                as RouteEndpoint;

            var routeTemplate =
                routeEndpoint
                    ?.RoutePattern
                    .RawText
                ?? context.Request.Path.Value
                ?? string.Empty;

            if (elapsedMilliseconds >=
                _options
                    .SlowRequestThresholdMilliseconds)
            {
                _logger.LogWarning(
                    SlowRequestEvent,
                    "Slow HTTP request. "
                    + "Method: {RequestMethod}, "
                    + "RouteTemplate: {RouteTemplate}, "
                    + "StatusCode: {StatusCode}, "
                    + "DurationMs: {DurationMs}, "
                    + "CorrelationId: {CorrelationId}.",
                    context.Request.Method,
                    routeTemplate,
                    context.Response.StatusCode,
                    elapsedMilliseconds,
                    context.TraceIdentifier);
            }
            else
            {
                _logger.LogInformation(
                    RequestTimingEvent,
                    "HTTP request timing. "
                    + "Method: {RequestMethod}, "
                    + "RouteTemplate: {RouteTemplate}, "
                    + "StatusCode: {StatusCode}, "
                    + "DurationMs: {DurationMs}, "
                    + "CorrelationId: {CorrelationId}.",
                    context.Request.Method,
                    routeTemplate,
                    context.Response.StatusCode,
                    elapsedMilliseconds,
                    context.TraceIdentifier);
            }
        }
    }

    private static bool IsHealthEndpoint(
        PathString path)
    {
        return path.StartsWithSegments(
            "/health",
            StringComparison.OrdinalIgnoreCase);
    }
}