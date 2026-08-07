namespace MindBloom.API.Middlewares;

public sealed class SecurityHeadersMiddleware
{
    private readonly RequestDelegate
        _next;

    private readonly IHostEnvironment
        _environment;

    public SecurityHeadersMiddleware(
        RequestDelegate next,
        IHostEnvironment environment)
    {
        _next =
            next;

        _environment =
            environment;
    }

    public async Task InvokeAsync(
        HttpContext context)
    {
        context.Response.OnStarting(
            () =>
            {
                ApplyCommonHeaders(
                    context);

                ApplyContentSecurityPolicy(
                    context);

                ApplySensitiveResponseCaching(
                    context);

                return Task.CompletedTask;
            });

        await _next(context);
    }

    private static void ApplyCommonHeaders(
        HttpContext context)
    {
        var headers =
            context.Response.Headers;

        headers[
            "X-Content-Type-Options"] =
            "nosniff";

        headers[
            "X-Frame-Options"] =
            "DENY";

        headers[
            "Referrer-Policy"] =
            "no-referrer";

        headers[
            "Permissions-Policy"] =
            "camera=(), microphone=(), geolocation=()";

        headers.Remove(
            "X-Powered-By");
    }

    private void ApplyContentSecurityPolicy(
        HttpContext context)
    {
        if (_environment.IsDevelopment() &&
            IsSwaggerRequest(
                context.Request.Path))
        {
            return;
        }

        context.Response.Headers[
            "Content-Security-Policy"] =
            "default-src 'none'; " +
            "base-uri 'none'; " +
            "frame-ancestors 'none'; " +
            "form-action 'none';";
    }

    private static void
        ApplySensitiveResponseCaching(
            HttpContext context)
    {
        if (!IsSensitiveRequest(
                context))
        {
            return;
        }

        var headers =
            context.Response.Headers;

        headers[
            "Cache-Control"] =
            "no-store, no-cache, must-revalidate";

        headers[
            "Pragma"] =
            "no-cache";

        headers[
            "Expires"] =
            "0";
    }

    private static bool IsSensitiveRequest(
        HttpContext context)
    {
        if (context.User.Identity?
                .IsAuthenticated ==
            true)
        {
            return true;
        }

        var path =
            context.Request.Path.Value
                ?.ToLowerInvariant()
            ?? string.Empty;

        return path.StartsWith(
                   "/api/auth",
                   StringComparison.Ordinal)
               ||
               path.StartsWith(
                   "/api/payments",
                   StringComparison.Ordinal)
               ||
               path.StartsWith(
                   "/api/memberships",
                   StringComparison.Ordinal);
    }

    private static bool IsSwaggerRequest(
        PathString path)
    {
        return path.StartsWithSegments(
                   "/swagger")
               ||
               path.StartsWithSegments(
                   "/swagger-ui");
    }
}