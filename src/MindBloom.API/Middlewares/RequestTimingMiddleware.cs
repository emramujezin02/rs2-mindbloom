using System.Diagnostics;
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

            if (elapsedMilliseconds >=
                _options
                    .SlowRequestThresholdMilliseconds)
            {
                _logger.LogWarning(
                    SlowRequestEvent,
                    "Slow HTTP request. "
                    + "Method: {RequestMethod}, "
                    + "Path: {RequestPath}, "
                    + "StatusCode: {StatusCode}, "
                    + "DurationMs: {DurationMs}.",
                    context.Request.Method,
                    context.Request.Path.Value,
                    context.Response.StatusCode,
                    elapsedMilliseconds);
            }
            else
            {
                _logger.LogInformation(
                    RequestTimingEvent,
                    "HTTP request timing. "
                    + "Method: {RequestMethod}, "
                    + "Path: {RequestPath}, "
                    + "StatusCode: {StatusCode}, "
                    + "DurationMs: {DurationMs}.",
                    context.Request.Method,
                    context.Request.Path.Value,
                    context.Response.StatusCode,
                    elapsedMilliseconds);
            }
        }
    }
}