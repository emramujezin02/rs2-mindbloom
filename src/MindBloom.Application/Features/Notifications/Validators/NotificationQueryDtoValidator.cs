using FluentValidation;
using MindBloom.Application.Features.Notifications.DTOs;

namespace MindBloom.Application.Features.Notifications.Validators;

public sealed class NotificationQueryDtoValidator
    : AbstractValidator<NotificationQueryDto>
{
    public NotificationQueryDtoValidator()
    {
        RuleFor(x => x.PageNumber)
            .GreaterThan(0)
            .WithMessage(
                "Page number must be greater than zero.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(1, 100)
            .WithMessage(
                "Page size must be between 1 and 100.");
    }
}