using System.Net;
using System.Text.Json;
using FluentValidation;
using MindBloom.API.Models;
using MindBloom.Application.Common.Exceptions;

namespace MindBloom.API.Middlewares;

public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;

    public GlobalExceptionMiddleware(
        RequestDelegate next)
    {
        _next = next;
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
                HttpStatusCode.NotFound,
                exception.Message);
        }
        catch (BusinessException exception)
        {
            await WriteErrorAsync(
                context,
                HttpStatusCode.Conflict,
                exception.Message);
        }
        catch (ArgumentException exception)
        {
            await WriteErrorAsync(
                context,
                HttpStatusCode.BadRequest,
                exception.Message);
        }
        catch (Exception exception)
        {
            await WriteErrorAsync(
                context,
                HttpStatusCode.InternalServerError,
                exception.Message);
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
                    StringComparer
                        .OrdinalIgnoreCase)
                .ToDictionary(
                    group => group.Key,
                    group => group
                        .Select(failure =>
                            failure.ErrorMessage)
                        .Distinct()
                        .ToArray(),
                    StringComparer
                        .OrdinalIgnoreCase);

        context.Response.StatusCode =
            (int)HttpStatusCode.BadRequest;

        context.Response.ContentType =
            "application/json";

        var response =
            new ValidationErrorResponse
            {
                Errors = errors
            };

        await context.Response.WriteAsync(
            JsonSerializer.Serialize(
                response));
    }

    private static async Task
        WriteErrorAsync(
            HttpContext context,
            HttpStatusCode statusCode,
            string message)
    {
        context.Response.StatusCode =
            (int)statusCode;

        context.Response.ContentType =
            "application/json";

        var response = new
        {
            message
        };

        await context.Response.WriteAsync(
            JsonSerializer.Serialize(
                response));
    }

    private static string ToCamelCase(
        string propertyName)
    {
        if (string.IsNullOrWhiteSpace(
                propertyName))
        {
            return "request";
        }

        if (propertyName.Length == 1)
        {
            return propertyName
                .ToLowerInvariant();
        }

        return
            char.ToLowerInvariant(
                propertyName[0])
            + propertyName[1..];
    }
}