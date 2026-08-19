using System.Security.Claims;
using System.Text;
using MindBloom.API.Security;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.API.Middlewares;

public sealed class AdminAuditMiddleware
{
    private static readonly EventId
    PreviousSnapshotFailedEvent =
        new(
            2200,
            "AdminAuditPreviousSnapshotFailed");

    private static readonly EventId
        NewSnapshotFailedEvent =
            new(
                2201,
                "AdminAuditNewSnapshotFailed");

    private static readonly EventId
        AuditWriteFailedEvent =
            new(
                2202,
                "AdminAuditWriteFailed");

    private const int MaximumRequestBodyLength =
        32_000;

    private readonly RequestDelegate _next;

    private readonly ILogger<AdminAuditMiddleware>
        _logger;

    public AdminAuditMiddleware(
        RequestDelegate next,
        ILogger<AdminAuditMiddleware> logger)
    {
        _next = next;

        _logger = logger;
    }

    public async Task InvokeAsync(
        HttpContext context,
        IAdminAuditService auditService,
        ApplicationDbContext dbContext)
    {
        if (!AdminAuditRequestResolver
                .ShouldAudit(context))
        {
            await _next(context);

            return;
        }

        var occurredAtUtc =
            DateTime.UtcNow;

        var entityType =
            AdminAuditRequestResolver
                .ResolveEntityType(
                    context);

        var entityId =
            AdminAuditRequestResolver
                .ResolveEntityId(
                    context);

        var requestBody =
            await ReadRequestBodyAsync(
                context);

        string? previousValues = null;

        try
        {
            previousValues =
                await AdminAuditSnapshotReader
                    .ReadAsync(
                        dbContext,
                        entityType,
                        entityId,
                        context,
                        context.RequestAborted);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                PreviousSnapshotFailedEvent,
                exception,
                "Previous admin audit snapshot could not be created. "
                + "EntityType: {EntityType}, "
                + "EntityId: {EntityId}, "
                + "CorrelationId: {CorrelationId}.",
                entityType,
                entityId,
                context.TraceIdentifier);
        }

        await _next(context);

        var statusCode =
            context.Response.StatusCode;

        var isSuccessful =
            statusCode >= 200 &&
            statusCode < 400;

        var adminUserId =
            ReadAdminUserId(context);

        var adminName =
            ResolveAdminName(context);

        var adminEmail =
            context.User.FindFirstValue(
                ClaimTypes.Email)
            ?? context.User.FindFirstValue(
                "email")
            ?? string.Empty;

        var ipAddress =
            context.Connection
                .RemoteIpAddress
                ?.ToString();

        string? newValues = null;

        if (isSuccessful &&
            entityId != null)
        {
            try
            {
                newValues =
                    await AdminAuditSnapshotReader
                        .ReadAsync(
                            dbContext,
                            entityType,
                            entityId,
                            context,
                            context.RequestAborted);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    NewSnapshotFailedEvent,
                    exception,
                    "New admin audit snapshot could not be created. "
                    + "EntityType: {EntityType}, "
                    + "EntityId: {EntityId}, "
                    + "CorrelationId: {CorrelationId}.",
                    entityType,
                    entityId,
                    context.TraceIdentifier);
            }
        }

        if (string.IsNullOrWhiteSpace(
                newValues))
        {
            newValues =
                AdminAuditDataSanitizer
                    .SanitizeJson(
                        requestBody,
                        context.Request.Path);
        }

        previousValues =
            AdminAuditDataSanitizer
                .SanitizeJson(
                    previousValues,
                    context.Request.Path);

        newValues =
            AdminAuditDataSanitizer
                .SanitizeJson(
                    newValues,
                    context.Request.Path);

        var auditRequest =
            new AdminAuditWriteDto
            {
                AdminUserId =
                    adminUserId,

                AdminName =
                    adminName,

                AdminEmail =
                    adminEmail,

                Action =
                    AdminAuditRequestResolver
                        .ResolveAction(
                            context),

                EntityType =
                    entityType,

                EntityId =
                    entityId,

                HttpMethod =
                    context.Request.Method,

                RequestPath =
                    context.Request.Path.Value
                    ?? string.Empty,

                PreviousValues =
                    previousValues,

                NewValues =
                    newValues,

                IpAddress =
                    ipAddress,

                CorrelationId =
                    context.TraceIdentifier,

                IsSuccessful =
                    isSuccessful,

                StatusCode =
                    statusCode,

                ResultMessage =
                    ResolveResultMessage(
                        statusCode,
                        isSuccessful),

                OccurredAtUtc =
                    occurredAtUtc
            };

        try
        {

            await auditService.WriteAsync(
                auditRequest,
                CancellationToken.None);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                AuditWriteFailedEvent,
                exception,
                "Admin audit log could not be saved. "
                + "CorrelationId: {CorrelationId}.",
                context.TraceIdentifier);
        }
    }

    private static async Task<string?>
        ReadRequestBodyAsync(
            HttpContext context)
    {
        if (context.Request.ContentLength
                is null or 0)
        {
            return null;
        }

        if (context.Request.ContentLength >
            MaximumRequestBodyLength)
        {
            return
                "{\"data\":\"[IZOSTAVLJENO ZBOG VELIČINE]\"}";
        }

        if (context.Request.ContentType
                ?.Contains(
                    "application/json",
                    StringComparison
                        .OrdinalIgnoreCase)
            != true)
        {
            return null;
        }

        context.Request.EnableBuffering();

        context.Request.Body.Position = 0;

        using var reader =
            new StreamReader(
                context.Request.Body,
                Encoding.UTF8,
                detectEncodingFromByteOrderMarks:
                    false,
                leaveOpen: true);

        var body =
            await reader.ReadToEndAsync();

        context.Request.Body.Position = 0;

        return body;
    }

    private static int? ReadAdminUserId(
        HttpContext context)
    {
        var userIdValue =
            context.User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        return int.TryParse(
                userIdValue,
                out var userId)
            ? userId
            : null;
    }

    private static string ResolveAdminName(
        HttpContext context)
    {
        var fullName =
            context.User.FindFirstValue(
                ClaimTypes.Name)
            ?? context.User.FindFirstValue(
                "name");

        if (!string.IsNullOrWhiteSpace(
                fullName))
        {
            return fullName.Trim();
        }

        var firstName =
            context.User.FindFirstValue(
                "firstName")
            ?? context.User.FindFirstValue(
                "given_name");

        var lastName =
            context.User.FindFirstValue(
                "lastName")
            ?? context.User.FindFirstValue(
                "family_name");

        var combined =
            $"{firstName} {lastName}"
                .Trim();

        return string.IsNullOrWhiteSpace(
                combined)
            ? "Administrator"
            : combined;
    }

    private static string ResolveResultMessage(
        int statusCode,
        bool isSuccessful)
    {
        if (isSuccessful)
        {
            return
                "Administrativna akcija je uspješno izvršena.";
        }

        return statusCode switch
        {
            400 =>
                "Zahtjev nije validan.",

            401 =>
                "Autentifikacija nije uspjela.",

            403 =>
                "Pristup akciji je odbijen.",

            404 =>
                "Traženi resurs nije pronađen.",

            409 =>
                "Akcija nije izvršena zbog poslovnog pravila.",

            >= 500 =>
                "Akcija nije izvršena zbog serverske greške.",

            _ =>
                "Administrativna akcija nije uspješno izvršena."
        };
    }
}