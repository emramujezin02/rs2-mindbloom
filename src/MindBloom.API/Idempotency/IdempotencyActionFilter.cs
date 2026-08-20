using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.API.Idempotency;

public sealed class IdempotencyActionFilter
    : IAsyncActionFilter
{
    private const string
        ProcessingStatus =
            "Processing";

    private const string
        CompletedStatus =
            "Completed";

    private static readonly JsonSerializerOptions
        JsonOptions =
            new(
                JsonSerializerDefaults.Web)
            {
                WriteIndented =
                    false
            };

    private readonly ApplicationDbContext
        _context;

    private readonly IdempotencyOptions
        _options;

    private readonly ILogger<
        IdempotencyActionFilter>
        _logger;

    public IdempotencyActionFilter(
        ApplicationDbContext context,
        IOptions<IdempotencyOptions> options,
        ILogger<IdempotencyActionFilter>
            logger)
    {
        _context =
            context;

        _options =
            options.Value;

        _logger =
            logger;
    }

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var cancellationToken =
            context.HttpContext
                .RequestAborted;

        var userId =
            ResolveUserId(
                context.HttpContext);

        var idempotencyKey =
            ResolveIdempotencyKey(
                context.HttpContext);

        var operation =
            ResolveOperation(
                context);

        var requestHash =
            CreateRequestHash(
                operation,
                context.ActionArguments);

        /*
         * Prvo tražimo postojeći key.
         */
        var existing =
            await _context
                .ApiIdempotencyRecords
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    record =>
                        record.IdempotencyKey ==
                            idempotencyKey,
                    cancellationToken);

        if (existing != null)
        {
            await HandleExistingAsync(
                context,
                existing,
                userId,
                operation,
                requestHash,
                cancellationToken);

            return;
        }

        var record =
            new ApiIdempotencyRecord
            {
                IdempotencyKey =
                    idempotencyKey,

                UserId =
                    userId,

                Operation =
                    operation,

                RequestHash =
                    requestHash,

                Status =
                    ProcessingStatus,

                CreatedAtUtc =
                    DateTime.UtcNow,

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddHours(
                            _options
                                .ExpirationHours)
            };

        _context.ApiIdempotencyRecords
            .Add(record);

        try
        {
            await _context
                .SaveChangesAsync(
                    cancellationToken);
        }
        catch (DbUpdateException)
        {
            /*
             * Drugi paralelni request je možda
             * upravo insertovao isti unique key.
             */
            _context
                .ChangeTracker
                .Clear();

            existing =
                await _context
                    .ApiIdempotencyRecords
                    .AsNoTracking()
                    .FirstOrDefaultAsync(
                        current =>
                            current
                                .IdempotencyKey ==
                            idempotencyKey,
                        cancellationToken);

            if (existing == null)
            {
                throw;
            }

            await HandleExistingAsync(
                context,
                existing,
                userId,
                operation,
                requestHash,
                cancellationToken);

            return;
        }

        ActionExecutedContext executed;

        try
        {
            executed =
                await next();
        }
        catch
        {
            /*
             * Neuspješan request ne cache-iramo
             * kao uspješan rezultat.
             *
             * Key uklanjamo kako bi korisnik
             * mogao legitimno ponoviti request.
             */
            var failedRecord =
                await _context
                    .ApiIdempotencyRecords
                    .FirstOrDefaultAsync(
                        current =>
                            current.Id ==
                            record.Id,
                        cancellationToken);

            if (failedRecord != null)
            {
                _context
                    .ApiIdempotencyRecords
                    .Remove(
                        failedRecord);

                await _context
                    .SaveChangesAsync(
                        cancellationToken);
            }

            throw;
        }

        /*
         * Ako exception nije bačen, spremamo
         * status code i response body.
         */
        var response =
            ExtractResponse(
                executed.Result);

        var storedRecord =
            await _context
                .ApiIdempotencyRecords
                .FirstOrDefaultAsync(
                    current =>
                        current.Id ==
                        record.Id,
                    cancellationToken);

        if (storedRecord == null)
        {
            return;
        }

        storedRecord.Status =
            CompletedStatus;

        storedRecord.ResponseStatusCode =
            response.StatusCode;

        storedRecord.ResponseBody =
            response.Body;

        storedRecord.CompletedAtUtc =
            DateTime.UtcNow;

        await _context
            .SaveChangesAsync(
                cancellationToken);

        _logger.LogInformation(
            "Idempotent API request completed. "
            + "Module: {Module}, "
            + "Operation: {Operation}, "
            + "UserId: {UserId}.",
            "Idempotency",
            operation,
            userId);
    }

    private async Task HandleExistingAsync(
        ActionExecutingContext context,
        ApiIdempotencyRecord existing,
        int userId,
        string operation,
        string requestHash,
        CancellationToken cancellationToken)
    {
        if (existing.ExpiresAtUtc <=
            DateTime.UtcNow)
        {
            /*
             * Expired record se ne smije
             * koristiti kao cache.
             */
            var expired =
                await _context
                    .ApiIdempotencyRecords
                    .FirstOrDefaultAsync(
                        record =>
                            record.Id ==
                            existing.Id,
                        cancellationToken);

            if (expired != null)
            {
                _context
                    .ApiIdempotencyRecords
                    .Remove(
                        expired);

                await _context
                    .SaveChangesAsync(
                        cancellationToken);
            }

            throw new BusinessException(
                "The idempotency key has expired. "
                + "Use a new idempotency key.");
        }

        /*
         * Key je vezan za jednog korisnika.
         */
        if (existing.UserId !=
            userId)
        {
            throw new BusinessException(
                "This idempotency key belongs "
                + "to another user.");
        }

        /*
         * Isti key ne smije biti korišten
         * za drugi endpoint.
         */
        if (!string.Equals(
                existing.Operation,
                operation,
                StringComparison.Ordinal))
        {
            throw new BusinessException(
                "The same idempotency key cannot "
                + "be reused for another operation.");
        }

        /*
         * Isti key + drugi payload = conflict.
         */
        if (!string.Equals(
                existing.RequestHash,
                requestHash,
                StringComparison.Ordinal))
        {
            throw new BusinessException(
                "The same idempotency key was "
                + "already used with a different request.");
        }

        if (string.Equals(
                existing.Status,
                CompletedStatus,
                StringComparison.Ordinal))
        {
            context.Result =
                CreateReplayResult(
                    existing);

            _logger.LogInformation(
                "Idempotent API response replayed. "
                + "Module: {Module}, "
                + "Operation: {Operation}, "
                + "UserId: {UserId}.",
                "Idempotency",
                operation,
                userId);

            return;
        }

        /*
         * Ako je prvi identični request još
         * u toku, kratko čekamo njegov rezultat.
         */
        var waitUntil =
            DateTime.UtcNow.AddMilliseconds(
                _options
                    .ProcessingWaitMilliseconds);

        while (DateTime.UtcNow <
               waitUntil)
        {
            await Task.Delay(
                _options
                    .ProcessingPollMilliseconds,
                cancellationToken);

            var refreshed =
                await _context
                    .ApiIdempotencyRecords
                    .AsNoTracking()
                    .FirstOrDefaultAsync(
                        record =>
                            record.Id ==
                            existing.Id,
                        cancellationToken);

            /*
             * Prvi request je možda pao i njegov
             * record je uklonjen.
             */
            if (refreshed == null)
            {
                throw new BusinessException(
                    "The previous request failed. "
                    + "Please retry with a new "
                    + "idempotency key.");
            }

            if (string.Equals(
                    refreshed.Status,
                    CompletedStatus,
                    StringComparison.Ordinal))
            {
                context.Result =
                    CreateReplayResult(
                        refreshed);

                return;
            }
        }

        throw new BusinessException(
            "An identical request with this "
            + "idempotency key is already "
            + "being processed.");
    }

    private string ResolveIdempotencyKey(
        HttpContext context)
    {
        if (!context.Request.Headers
                .TryGetValue(
                    _options.HeaderName,
                    out var values))
        {
            throw new BusinessException(
                $"{_options.HeaderName} header "
                + "is required for this operation.");
        }

        var value =
            values.FirstOrDefault()
                ?.Trim();

        if (string.IsNullOrWhiteSpace(
                value))
        {
            throw new BusinessException(
                $"{_options.HeaderName} header "
                + "cannot be empty.");
        }

        if (value.Length >
            _options.MaximumKeyLength)
        {
            throw new BusinessException(
                $"{_options.HeaderName} is too long.");
        }

        return value;
    }

    private static int ResolveUserId(
        HttpContext context)
    {
        var value =
            context.User
                .FindFirstValue(
                    ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId) ||
            userId <= 0)
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier "
                + "is missing or invalid.");
        }

        return userId;
    }

    private static string ResolveOperation(
        ActionExecutingContext context)
    {
        var descriptor =
            context.ActionDescriptor;

        var controller =
            descriptor.RouteValues
                .TryGetValue(
                    "controller",
                    out var controllerValue)
                ? controllerValue
                : "Unknown";

        var action =
            descriptor.RouteValues
                .TryGetValue(
                    "action",
                    out var actionValue)
                ? actionValue
                : "Unknown";

        return
            $"{controller}.{action}";
    }

    private static string CreateRequestHash(
        string operation,
        IDictionary<string, object?>
            actionArguments)
    {
        var normalized =
            new SortedDictionary<
                string,
                object?>(
                StringComparer.Ordinal);

        foreach (var argument
                 in actionArguments)
        {
            normalized[
                argument.Key] =
                    argument.Value;
        }

        var serialized =
            JsonSerializer.Serialize(
                normalized,
                JsonOptions);

        var input =
            operation
            + "\n"
            + serialized;

        var bytes =
            SHA256.HashData(
                Encoding.UTF8
                    .GetBytes(
                        input));

        return Convert.ToHexString(
            bytes);
    }

    private static StoredResponse
        ExtractResponse(
            IActionResult? result)
    {
        switch (result)
        {
            case ObjectResult objectResult:
                {
                    var statusCode =
                        objectResult.StatusCode
                        ?? StatusCodes
                            .Status200OK;

                    var body =
                        objectResult.Value == null
                            ? null
                            : JsonSerializer
                                .Serialize(
                                    objectResult.Value,
                                    objectResult.Value
                                        .GetType(),
                                    JsonOptions);

                    return new StoredResponse(
                        statusCode,
                        body);
                }

            case StatusCodeResult
                statusCodeResult:
                return new StoredResponse(
                    statusCodeResult
                        .StatusCode,
                    null);

            case EmptyResult:
                return new StoredResponse(
                    StatusCodes
                        .Status204NoContent,
                    null);

            case null:
                return new StoredResponse(
                    StatusCodes
                        .Status204NoContent,
                    null);

            default:

                throw new InvalidOperationException(
                    "The idempotency filter cannot "
                    + "cache this action result type.");
        }
    }

    private static IActionResult
        CreateReplayResult(
            ApiIdempotencyRecord record)
    {
        var statusCode =
            record.ResponseStatusCode
            ?? StatusCodes.Status200OK;

        if (string.IsNullOrWhiteSpace(
                record.ResponseBody))
        {
            return new StatusCodeResult(
                statusCode);
        }

        return new ContentResult
        {
            StatusCode =
                statusCode,

            ContentType =
                "application/json",

            Content =
                record.ResponseBody
        };
    }

    private sealed record StoredResponse(
        int StatusCode,
        string? Body);
}