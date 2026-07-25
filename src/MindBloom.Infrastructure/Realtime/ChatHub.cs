using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Chat.DTOs;
using MindBloom.Application.Features.Chat.Interfaces;

namespace MindBloom.Infrastructure.Realtime;

[Authorize]
public sealed class ChatHub : Hub
{
    private readonly IChatService
        _chatService;

    private readonly IValidator<SendChatMessageDto>
        _messageValidator;

    public ChatHub(
        IChatService chatService,
        IValidator<SendChatMessageDto>
            messageValidator)
    {
        _chatService =
            chatService;

        _messageValidator =
            messageValidator;
    }

    public async Task JoinConversation(
        int conversationId)
    {
        var userId =
            GetCurrentUserId();

        var isParticipant =
            await _chatService
                .IsParticipantAsync(
                    userId,
                    conversationId);

        if (!isParticipant)
        {
            throw new ForbiddenException(
                "You are not allowed to join this conversation.");
        }

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            GetConversationGroupName(
                conversationId));

        await _chatService
            .MarkConversationAsReadAsync(
                userId,
                conversationId);
    }

    public async Task LeaveConversation(
        int conversationId)
    {
        var userId =
            GetCurrentUserId();

        var isParticipant =
            await _chatService
                .IsParticipantAsync(
                    userId,
                    conversationId);

        if (!isParticipant)
        {
            throw new HubException(
                "You are not a participant in this conversation.");
        }

        await Groups.RemoveFromGroupAsync(
            Context.ConnectionId,
            GetConversationGroupName(
                conversationId));
    }

    public async Task SendMessage(
        int conversationId,
        string content,
        string clientMessageId)
    {
        var userId =
            GetCurrentUserId();

        var request =
            new SendChatMessageDto
            {
                ConversationId =
                    conversationId,

                Content =
                    content,

                ClientMessageId =
                    clientMessageId
            };

        var validationResult =
            await _messageValidator
                .ValidateAsync(
                    request);

        if (!validationResult.IsValid)
        {
            var message =
                string.Join(
                    " ",
                    validationResult.Errors
                        .Select(x =>
                            x.ErrorMessage));

            throw new HubException(
                message);
        }

        var result =
            await _chatService
                .SendMessageAsync(
                    userId,
                    request);

        await Clients.Caller.SendAsync(
            "ReceiveMessage",
            result);

        var recipientResult =
            new ChatMessageResponseDto
            {
                Id =
                    result.Id,

                ConversationId =
                    result.ConversationId,

                SenderUserId =
                    result.SenderUserId,

                SenderName =
                    result.SenderName,

                Content =
                    result.Content,

                SentAtUtc =
                    result.SentAtUtc,

                IsMine =
                    false,

                IsEdited =
                    result.IsEdited,

                ClientMessageId =
                    result.ClientMessageId
            };

        await Clients
            .OthersInGroup(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "ReceiveMessage",
                recipientResult);
    }

    private int GetCurrentUserId()
    {
        var userIdValue =
            Context.User?
                .FindFirstValue(
                    ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new HubException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }

    private static string
        GetConversationGroupName(
            int conversationId)
    {
        return $"conversation-{conversationId}";
    }
}