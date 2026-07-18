using System.Security.Claims;
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

    public ChatHub(
        IChatService chatService)
    {
        _chatService =
            chatService;
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
        string content)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _chatService
                .SendMessageAsync(
                    userId,
                    new SendChatMessageDto
                    {
                        ConversationId =
                            conversationId,

                        Content =
                            content
                    });

        await Clients
            .Group(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "ReceiveMessage",
                result);
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