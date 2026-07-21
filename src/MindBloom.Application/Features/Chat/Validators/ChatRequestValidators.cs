using FluentValidation;
using MindBloom.Application.Features.Chat.DTOs;

namespace MindBloom.Application.Features.Chat.Validators;

public static class ChatValidationRules
{
    public const int MaximumMessageLength = 2000;
    public const int MaximumPageSize = 100;
}

public sealed class SendChatMessageDtoValidator
    : AbstractValidator<SendChatMessageDto>
{
    public SendChatMessageDtoValidator()
    {
        RuleFor(x => x.ConversationId)
            .GreaterThan(0)
            .WithMessage(
                "Conversation ID must be greater than zero.");

        RuleFor(x => x.Content)
            .NotEmpty()
            .WithMessage(
                "Message content is required.")
            .Must(x =>
                !string.IsNullOrWhiteSpace(x))
            .WithMessage(
                "Message content is required.")
            .MaximumLength(
                ChatValidationRules.MaximumMessageLength)
            .WithMessage(
                "Message may contain at most 2000 characters.");
    }
}

public sealed class ChatPagingQueryDtoValidator
    : AbstractValidator<ChatPagingQueryDto>
{
    public ChatPagingQueryDtoValidator()
    {
        RuleFor(x => x.PageNumber)
            .GreaterThan(0)
            .WithMessage(
                "Page number must be greater than zero.");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(
                1,
                ChatValidationRules.MaximumPageSize)
            .WithMessage(
                "Page size must be between 1 and 100.");
    }
}