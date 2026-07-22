using System.Diagnostics;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;

namespace MindBloom.API.Middlewares;

public sealed class RequestTimingMiddleware
{
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

        await _next(context);

        stopwatch.Stop();

        var elapsedMilliseconds =
            stopwatch.ElapsedMilliseconds;

        if (elapsedMilliseconds <
            _options
                .SlowRequestThresholdMilliseconds)
        {
            return;
        }

        _logger.LogWarning(
            "Slow request detected. Method: {Method}, Path: {Path}, StatusCode: {StatusCode}, DurationMs: {DurationMs}, CorrelationId: {CorrelationId}.",
            context.Request.Method,
            context.Request.Path,
            context.Response.StatusCode,
            elapsedMilliseconds,
            context.TraceIdentifier);
    }
}