using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using MindBloom.API.Models;

namespace MindBloom.API.Filters;

public sealed class FluentValidationFilter
    : IAsyncActionFilter
{
    private readonly IServiceProvider
        _serviceProvider;

    public FluentValidationFilter(
        IServiceProvider serviceProvider)
    {
        _serviceProvider =
            serviceProvider;
    }

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var validationErrors =
            new Dictionary<string, List<string>>(
                StringComparer.OrdinalIgnoreCase);

        foreach (var argument
                 in context.ActionArguments.Values)
        {
            if (argument == null)
            {
                continue;
            }

            var argumentType =
                argument.GetType();

            var validatorType =
                typeof(IValidator<>)
                    .MakeGenericType(
                        argumentType);

            var validators =
                _serviceProvider
                    .GetServices(
                        validatorType)
                    .OfType<IValidator>()
                    .ToList();

            foreach (var validator
                     in validators)
            {
                var validationContext =
                    new ValidationContext<object>(
                        argument);

                var result =
                    await validator.ValidateAsync(
                        validationContext,
                        context.HttpContext
                            .RequestAborted);

                foreach (var failure
                         in result.Errors)
                {
                    if (failure == null ||
                        string.IsNullOrWhiteSpace(
                            failure.ErrorMessage))
                    {
                        continue;
                    }

                    var propertyName =
                        ToCamelCase(
                            failure.PropertyName);

                    if (!validationErrors
                            .TryGetValue(
                                propertyName,
                                out var messages))
                    {
                        messages = [];

                        validationErrors[
                            propertyName] =
                            messages;
                    }

                    if (!messages.Contains(
                            failure.ErrorMessage,
                            StringComparer.Ordinal))
                    {
                        messages.Add(
                            failure.ErrorMessage);
                    }
                }
            }
        }

        if (validationErrors.Count > 0)
        {
            context.Result =
                new BadRequestObjectResult(
                    new ApiErrorResponse
                    {
                        StatusCode =
                            StatusCodes
                                .Status400BadRequest,

                        Title =
                            "Validation failed",

                        Detail =
                            "One or more validation errors occurred.",

                        ValidationErrors =
                            validationErrors
                                .ToDictionary(
                                    item => item.Key,
                                    item => item.Value
                                        .ToArray(),
                                    StringComparer
                                        .OrdinalIgnoreCase)
                    });

            return;
        }

        await next();
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
}