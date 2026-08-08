using Microsoft.AspNetCore.Http;
using MindBloom.Application.Features.Security.DTOs;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class SecurityAuditService
    : ISecurityAuditService
{
    private readonly ApplicationDbContext
        _context;

    private readonly IHttpContextAccessor
        _httpContextAccessor;

    public SecurityAuditService(
        ApplicationDbContext context,
        IHttpContextAccessor httpContextAccessor)
    {
        _context =
            context;

        _httpContextAccessor =
            httpContextAccessor;
    }

    public async Task WriteAsync(
        SecurityAuditWriteDto request,
        CancellationToken cancellationToken =
            default)
    {
        ArgumentNullException.ThrowIfNull(
            request);

        if (string.IsNullOrWhiteSpace(
                request.EventType))
        {
            throw new ArgumentException(
                "Security audit event type is required.",
                nameof(request));
        }

        var httpContext =
            _httpContextAccessor
                .HttpContext;

        var audit =
            new SecurityAuditLog
            {
                UserId =
                    request.UserId,

                EventType =
                    Limit(
                        request.EventType,
                        150),

                IsSuccessful =
                    request.IsSuccessful,

                FailureReason =
                    LimitNullable(
                        request.FailureReason,
                        500),

                ResourceType =
                    LimitNullable(
                        request.ResourceType,
                        150),

                ResourceId =
                    LimitNullable(
                        request.ResourceId,
                        100),

                IpAddress =
                    LimitNullable(
                        httpContext?
                            .Connection
                            .RemoteIpAddress?
                            .ToString(),
                        100),

                UserAgent =
                    LimitNullable(
                        httpContext?
                            .Request
                            .Headers
                            .UserAgent
                            .ToString(),
                        500),

                CorrelationId =
                    LimitNullable(
                        httpContext?
                            .TraceIdentifier,
                        100),

                OccurredAtUtc =
                    DateTime.UtcNow,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        _context.SecurityAuditLogs.Add(
            audit);

        await _context
            .SaveChangesAsync(
                cancellationToken);
    }

    private static string Limit(
        string value,
        int maximumLength)
    {
        var normalized =
            value.Trim();

        return normalized.Length <=
               maximumLength
            ? normalized
            : normalized[
                ..maximumLength];
    }

    private static string? LimitNullable(
        string? value,
        int maximumLength)
    {
        if (string.IsNullOrWhiteSpace(
                value))
        {
            return null;
        }

        var normalized =
            value.Trim();

        return normalized.Length <=
               maximumLength
            ? normalized
            : normalized[
                ..maximumLength];
    }
}