using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using MindBloom.API.Models;

namespace MindBloom.API.Filters;

public sealed class FluentValidationFilter
    : IAsyncActionFilter
{
    private readonly IServiceProvider _serviceProvider;

    public FluentValidationFilter(
        IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
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
                    .MakeGenericType(argumentType);

            var validators =
                _serviceProvider
                    .GetServices(validatorType)
                    .OfType<IValidator>()
                    .ToList();

            foreach (var validator in validators)
            {
                var validationContext =
                    new ValidationContext<object>(
                        argument);

                var validationResult =
                    await validator.ValidateAsync(
                        validationContext,
                        context.HttpContext
                            .RequestAborted);

                foreach (var failure
                         in validationResult.Errors)
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

                    if (!validationErrors.TryGetValue(
                            propertyName,
                            out var messages))
                    {
                        messages = [];

                        validationErrors[propertyName] =
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
                    new ValidationErrorResponse
                    {
                        Errors =
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

        if (propertyName.Length == 1)
        {
            return propertyName.ToLowerInvariant();
        }

        return
            char.ToLowerInvariant(
                propertyName[0])
            + propertyName[1..];
    }
}