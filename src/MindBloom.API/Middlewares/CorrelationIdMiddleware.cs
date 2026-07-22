using System.Diagnostics;
using System.Text.RegularExpressions;

namespace MindBloom.API.Middlewares;

public sealed partial class CorrelationIdMiddleware
{
    public const string HeaderName =
        "X-Correlation-ID";

    private const int MaximumCorrelationIdLength =
        100;

    private readonly RequestDelegate _next;

    private readonly ILogger<CorrelationIdMiddleware>
        _logger;

    public CorrelationIdMiddleware(
        RequestDelegate next,
        ILogger<CorrelationIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
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

        using (_logger.BeginScope(
                   new Dictionary<string, object>
                   {
                       ["CorrelationId"] =
                           correlationId
                   }))
        {
            _logger.LogInformation(
                "Request started. Method: {RequestMethod}, Path: {RequestPath}.",
                context.Request.Method,
                context.Request.Path);

            try
            {
                await _next(context);

                _logger.LogInformation(
                    "Request completed. Method: {RequestMethod}, Path: {RequestPath}, StatusCode: {StatusCode}.",
                    context.Request.Method,
                    context.Request.Path,
                    context.Response.StatusCode);
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Request failed. Method: {RequestMethod}, Path: {RequestPath}.",
                    context.Request.Method,
                    context.Request.Path);

                throw;
            }
        }
    }

    private static readonly Regex
    CorrelationIdPattern =
        new(
            "^[A-Za-z0-9._-]+$",
            RegexOptions.CultureInvariant |
            RegexOptions.Compiled);

    private static string ResolveCorrelationId(
        HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(
                HeaderName,
                out var headerValues))
        {
            var providedCorrelationId =
                headerValues.FirstOrDefault()
                    ?.Trim();

            if (IsValidCorrelationId(
                    providedCorrelationId))
            {
                return providedCorrelationId!;
            }
        }

        return Guid.NewGuid()
            .ToString("N");
    }

    private static bool IsValidCorrelationId(
        string? correlationId)
    {
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

        return CorrelationIdPattern
            .IsMatch(correlationId);
    }


}