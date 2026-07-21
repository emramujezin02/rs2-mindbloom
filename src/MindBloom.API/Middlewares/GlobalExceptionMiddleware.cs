using System.Net;
using System.Text.Json;
using FluentValidation;
using MindBloom.API.Models;
using MindBloom.Application.Common.Exceptions;

namespace MindBloom.API.Middlewares;

public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware>
        _logger;

    public GlobalExceptionMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(
        HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ValidationException exception)
        {
            await WriteValidationErrorAsync(
                context,
                exception);
        }
        catch (NotFoundException exception)
        {
            await WriteErrorAsync(
                context,
                StatusCodes.Status404NotFound,
                "Resource not found",
                exception.Message);
        }
        catch (BadRequestException exception)
        {
            await WriteErrorAsync(
                context,
                StatusCodes.Status400BadRequest,
                "Bad request",
                exception.Message);
        }
        catch (BusinessException exception)
        {
            await WriteErrorAsync(
                context,
                StatusCodes.Status409Conflict,
                "Business rule violation",
                exception.Message);
        }
        catch (ArgumentException exception)
        {
            await WriteErrorAsync(
                context,
                StatusCodes.Status400BadRequest,
                "Bad request",
                exception.Message);
        }
        catch (UnauthorizedAccessException exception)
        {
            await WriteErrorAsync(
                context,
                StatusCodes.Status401Unauthorized,
                "Unauthorized",
                exception.Message);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "An unhandled exception occurred.");

            await WriteErrorAsync(
                context,
                StatusCodes.Status500InternalServerError,
                "Internal server error",
                "An unexpected server error occurred.");
        }
    }

    private static async Task
        WriteValidationErrorAsync(
            HttpContext context,
            ValidationException exception)
    {
        var errors =
            exception.Errors
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

        var response =
            new ApiErrorResponse
            {
                StatusCode =
                    StatusCodes.Status400BadRequest,

                Title =
                    "Validation failed",

                Detail =
                    "One or more validation errors occurred.",

                ValidationErrors =
                    errors
            };

        await WriteResponseAsync(
            context,
            response);
    }

    private static async Task WriteErrorAsync(
        HttpContext context,
        int statusCode,
        string title,
        string detail)
    {
        var response =
            new ApiErrorResponse
            {
                StatusCode = statusCode,
                Title = title,
                Detail = detail,
                ValidationErrors = null
            };

        await WriteResponseAsync(
            context,
            response);
    }

    private static async Task WriteResponseAsync(
        HttpContext context,
        ApiErrorResponse response)
    {
        context.Response.StatusCode =
            response.StatusCode;

        context.Response.ContentType =
            "application/problem+json";

        var json =
            JsonSerializer.Serialize(
                response,
                new JsonSerializerOptions
                {
                    PropertyNamingPolicy =
                        JsonNamingPolicy.CamelCase
                });

        await context.Response.WriteAsync(json);
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
            return normalized.ToLowerInvariant();
        }

        return
            char.ToLowerInvariant(
                normalized[0])
            + normalized[1..];
    }
}