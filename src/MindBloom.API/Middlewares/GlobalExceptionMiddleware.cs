using System.Text.Json;
using FluentValidation;
using MindBloom.API.Models;
using MindBloom.Application.Common.Exceptions;

namespace MindBloom.API.Middlewares;

public sealed class GlobalExceptionMiddleware
{

    private static readonly EventId
    UnhandledExceptionEvent =
        new(
            2000,
            "UnhandledException");

    private static readonly EventId
        AuthorizationExceptionEvent =
            new(
                2001,
                "AuthorizationException");

    private static readonly EventId
        HandledApplicationExceptionEvent =
            new(
                2002,
                "HandledApplicationException");

    private static readonly EventId
        ResponseAlreadyStartedEvent =
            new(
                2003,
                "ResponseAlreadyStarted");

    private static readonly JsonSerializerOptions
        JsonOptions =
            new()
            {
                PropertyNamingPolicy =
                    JsonNamingPolicy.CamelCase,

                DefaultIgnoreCondition =
                    System.Text.Json.Serialization
                        .JsonIgnoreCondition
                        .WhenWritingNull
            };

    private readonly RequestDelegate _next;

    private readonly ILogger<GlobalExceptionMiddleware>
        _logger;

    private readonly IHostEnvironment
        _environment;

    public GlobalExceptionMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionMiddleware> logger,
        IHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(
        HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception exception)
        {
            await HandleExceptionAsync(
                context,
                exception);
        }
    }

    private async Task HandleExceptionAsync(
        HttpContext context,
        Exception exception)
    {
        if (context.Response.HasStarted)
        {
            _logger.LogWarning(
    ResponseAlreadyStartedEvent,
    exception,
    "The response has already started. "
    + "The exception middleware cannot write an error response.");

            throw exception;
        }

        var errorDefinition =
            MapException(exception);

        LogException(
            exception,
            errorDefinition.StatusCode,
            context);

        var response =
            new ApiErrorResponse
            {
                StatusCode =
                    errorDefinition.StatusCode,

                Title =
                    errorDefinition.Title,

                Detail =
                    GetDetail(
                        exception,
                        errorDefinition),

                TraceId =
                    context.TraceIdentifier,

                ValidationErrors =
                    errorDefinition.ValidationErrors,

                ExceptionType = null,

                StackTrace = null
            };

        context.Response.Clear();

        context.Response.StatusCode =
            response.StatusCode;

        context.Response.ContentType =
            "application/problem+json";

        var json =
            JsonSerializer.Serialize(
                response,
                JsonOptions);

        await context.Response.WriteAsync(
            json,
            context.RequestAborted);
    }

    private static ErrorDefinition MapException(
        Exception exception)
    {
        return exception switch
        {
            ValidationException
                validationException =>
                    new ErrorDefinition(
                        StatusCodes.Status400BadRequest,
                        "Validation failed",
                        "One or more validation errors occurred.",
                        CreateValidationErrors(
                            validationException)),

            BadRequestException =>
                new ErrorDefinition(
                    StatusCodes.Status400BadRequest,
                    "Bad request",
                    exception.Message),

            NotFoundException =>
                new ErrorDefinition(
                    StatusCodes.Status404NotFound,
                    "Resource not found",
                    exception.Message),

            BusinessException =>
                new ErrorDefinition(
                    StatusCodes.Status409Conflict,
                    "Business rule violation",
                    exception.Message),

            UnauthorizedAccessException =>
                new ErrorDefinition(
                    StatusCodes.Status401Unauthorized,
                    "Unauthorized",
                    string.IsNullOrWhiteSpace(
                        exception.Message)
                        ? "Authentication is required."
                        : exception.Message),

            ArgumentNullException =>
                new ErrorDefinition(
                    StatusCodes.Status400BadRequest,
                    "Bad request",
                    exception.Message),

            ArgumentOutOfRangeException =>
                new ErrorDefinition(
                    StatusCodes.Status400BadRequest,
                    "Bad request",
                    exception.Message),

            ArgumentException =>
                new ErrorDefinition(
                    StatusCodes.Status400BadRequest,
                    "Bad request",
                    exception.Message),

            KeyNotFoundException =>
                new ErrorDefinition(
                    StatusCodes.Status404NotFound,
                    "Resource not found",
                    exception.Message),

            InvalidOperationException =>
                new ErrorDefinition(
                    StatusCodes.Status409Conflict,
                    "Invalid operation",
                    exception.Message),

            OperationCanceledException =>
                new ErrorDefinition(
                    StatusCodes.Status499ClientClosedRequest,
                    "Request cancelled",
                    "The request was cancelled."),

            _ =>
                new ErrorDefinition(
                    StatusCodes
                        .Status500InternalServerError,
                    "Internal server error",
                    "An unexpected server error occurred.")
        };
    }

    private string GetDetail(
        Exception exception,
        ErrorDefinition errorDefinition)
    {
        if (errorDefinition.StatusCode !=
            StatusCodes.Status500InternalServerError)
        {
            return errorDefinition.Detail;
        }

        if (_environment.IsDevelopment())
        {
            return exception.Message;
        }

        return "An unexpected server error occurred.";
    }

    private void LogException(
     Exception exception,
     int statusCode,
     HttpContext context)
    {
        var requestPath =
            context.Request.Path.Value
            ?? string.Empty;

        var requestMethod =
            context.Request.Method;

        var correlationId =
            context.TraceIdentifier;

        if (statusCode >=
            StatusCodes.Status500InternalServerError)
        {
            _logger.LogError(
                UnhandledExceptionEvent,
                exception,
                "Unhandled server exception. "
                + "Method: {RequestMethod}, "
                + "Path: {RequestPath}, "
                + "CorrelationId: {CorrelationId}, "
                + "StatusCode: {StatusCode}, "
                + "Module: {Module}, "
                + "Environment: {Environment}.",
                requestMethod,
                requestPath,
                correlationId,
                statusCode,
                "API",
                _environment.EnvironmentName);

            return;
        }

        if (statusCode ==
                StatusCodes.Status401Unauthorized ||
            statusCode ==
                StatusCodes.Status403Forbidden)
        {
            _logger.LogWarning(
                AuthorizationExceptionEvent,
                "Authorization request failed. "
                + "Method: {RequestMethod}, "
                + "Path: {RequestPath}, "
                + "CorrelationId: {CorrelationId}, "
                + "StatusCode: {StatusCode}, "
                + "ExceptionType: {ExceptionType}.",
                requestMethod,
                requestPath,
                correlationId,
                statusCode,
                exception.GetType().Name);

            return;
        }

        _logger.LogInformation(
            HandledApplicationExceptionEvent,
            "Handled application exception. "
            + "Method: {RequestMethod}, "
            + "Path: {RequestPath}, "
            + "CorrelationId: {CorrelationId}, "
            + "StatusCode: {StatusCode}, "
            + "ExceptionType: {ExceptionType}.",
            requestMethod,
            requestPath,
            correlationId,
            statusCode,
            exception.GetType().Name);
    }

    private static IDictionary<string, string[]>
        CreateValidationErrors(
            ValidationException exception)
    {
        return exception.Errors
            .Where(failure =>
                failure != null &&
                !string.IsNullOrWhiteSpace(
                    failure.ErrorMessage))
            .GroupBy(
                failure =>
                    ToCamelCase(
                        failure.PropertyName),
                StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                group => group.Key,
                group => group
                    .Select(failure =>
                        failure.ErrorMessage)
                    .Distinct()
                    .ToArray(),
                StringComparer.OrdinalIgnoreCase);
    }

    private static string ToCamelCase(
        string propertyName)
    {
        if (string.IsNullOrWhiteSpace(
                propertyName))
        {
            return "request";
        }

        var normalized =
            propertyName.Trim();

        if (normalized.StartsWith(
                "$.",
                StringComparison.Ordinal))
        {
            normalized =
                normalized[2..];
        }

        if (normalized.Length == 1)
        {
            return normalized
                .ToLowerInvariant();
        }

        return
            char.ToLowerInvariant(
                normalized[0])
            + normalized[1..];
    }

    private sealed record ErrorDefinition(
        int StatusCode,
        string Title,
        string Detail,
        IDictionary<string, string[]>?
            ValidationErrors = null);
}