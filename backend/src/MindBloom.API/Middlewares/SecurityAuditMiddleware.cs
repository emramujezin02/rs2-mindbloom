using System.Security.Claims;
using MindBloom.Application.Features.Security.DTOs;
using MindBloom.Application.Features.Security.Interfaces;

namespace MindBloom.API.Middlewares;

public sealed class SecurityAuditMiddleware
{
    private static readonly EventId
    SecurityAuditWriteFailedEvent =
        new(
            2300,
            "SecurityAuditWriteFailed");

    private readonly RequestDelegate
        _next;

    private readonly ILogger<
        SecurityAuditMiddleware>
        _logger;

    public SecurityAuditMiddleware(
        RequestDelegate next,
        ILogger<SecurityAuditMiddleware> logger)
    {
        _next =
            next;

        _logger =
            logger;
    }

    public async Task InvokeAsync(
        HttpContext context,
        ISecurityAuditService
            securityAuditService)
    {
        await _next(context);

        if (context.Response.StatusCode !=
                StatusCodes
                    .Status401Unauthorized &&
            context.Response.StatusCode !=
                StatusCodes
                    .Status403Forbidden)
        {
            return;
        }

        if (IsAuthenticationEndpoint(
                context.Request.Path))
        {
            return;
        }

        int? userId =
            null;

        var userIdValue =
            context.User
                .FindFirstValue(
                    ClaimTypes
                        .NameIdentifier);

        if (int.TryParse(
                userIdValue,
                out var parsedUserId) &&
            parsedUserId > 0)
        {
            userId =
                parsedUserId;
        }

        var eventType =
            context.Response.StatusCode ==
            StatusCodes.Status403Forbidden
                ? "ForbiddenAccessAttempt"
                : "UnauthorizedAccessAttempt";

        var reason =
            context.Response.StatusCode ==
            StatusCodes.Status403Forbidden
                ? "InsufficientPermissions"
                : "AuthenticationRequiredOrInvalid";

        try
        {
            await securityAuditService
                .WriteAsync(
                    new SecurityAuditWriteDto
                    {
                        UserId =
                            userId,

                        EventType =
                            eventType,

                        IsSuccessful =
                            false,

                        FailureReason =
                            reason,

                        CorrelationId =
    context.TraceIdentifier,

                        ResourceType =
                            "HttpEndpoint",

                        ResourceId =
                            CreateSafeResourceId(
                                context)
                    },
                    context.RequestAborted);
        }
        catch (OperationCanceledException)
            when (context.RequestAborted
                .IsCancellationRequested)
        {

        }
        catch (Exception exception)
        {
            _logger.LogError(
                SecurityAuditWriteFailedEvent,
                exception,
                "Security audit could not be written for denied request. "
                + "Module: {Module}, "
                + "StatusCode: {StatusCode}, "
                + "Method: {Method}, "
                + "Path: {Path}, "
                + "CorrelationId: {CorrelationId}.",
                "SecurityAudit",
                context.Response.StatusCode,
                context.Request.Method,
                context.Request.Path.Value,
                context.TraceIdentifier);
        }
    }

    private static bool
        IsAuthenticationEndpoint(
            PathString path)
    {
        var value =
            path.Value
                ?.ToLowerInvariant()
            ?? string.Empty;

        return
            value.EndsWith(
                "/api/auth/login",
                StringComparison.Ordinal)
            ||
            value.EndsWith(
                "/api/auth/login-2fa",
                StringComparison.Ordinal)
            ||
            value.EndsWith(
                "/api/auth/verify-2fa",
                StringComparison.Ordinal);
    }

    private static string
        CreateSafeResourceId(
            HttpContext context)
    {
        var value =
            $"{context.Request.Method} "
            + $"{context.Request.Path}";

        const int maximumLength =
            100;

        return value.Length <=
               maximumLength
            ? value
            : value[
                ..maximumLength];
    }
}