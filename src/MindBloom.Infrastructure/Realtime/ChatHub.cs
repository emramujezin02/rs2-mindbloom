using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
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
    private readonly ILogger<ChatHub>
    _logger;
    private readonly IChatMessageRateLimiter
    _messageRateLimiter;

    public ChatHub(
        IChatService chatService,
        IValidator<SendChatMessageDto>
            messageValidator,
        IChatMessageRateLimiter
            messageRateLimiter,
        ILogger<ChatHub> logger)
    {
        _chatService =
            chatService;

        _messageValidator =
            messageValidator;

        _messageRateLimiter =
            messageRateLimiter;

        _logger =
            logger;
    }

    public override async Task OnConnectedAsync()
    {
        try
        {
            var userId =
                GetCurrentUserId();

            _logger.LogInformation(
                "Authenticated chat connection established. "
                + "UserId: {UserId}, "
                + "ConnectionId: {ConnectionId}.",
                userId,
                Context.ConnectionId);

            await base.OnConnectedAsync();
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Chat connection rejected because "
                + "the authenticated user identity "
                + "could not be resolved. "
                + "ConnectionId: {ConnectionId}.",
                Context.ConnectionId);

            Context.Abort();

            throw;
        }
    }

    public override async Task OnDisconnectedAsync(
    Exception? exception)
    {
        var userIdValue =
            Context.User?
                .FindFirstValue(
                    ClaimTypes.NameIdentifier);

        if (int.TryParse(
                userIdValue,
                out var userId))
        {
            if (exception == null)
            {
                _logger.LogInformation(
                    "Chat connection disconnected. "
                    + "UserId: {UserId}, "
                    + "ConnectionId: {ConnectionId}.",
                    userId,
                    Context.ConnectionId);
            }
            else
            {
                _logger.LogWarning(
                    "Chat connection disconnected unexpectedly. "
                    + "UserId: {UserId}, "
                    + "ConnectionId: {ConnectionId}.",
                    userId,
                    Context.ConnectionId);
            }
        }

        await base.OnDisconnectedAsync(
            exception);
    }


    public async Task JoinConversation(
        int conversationId)
    {
        var userId =
            GetCurrentUserId();

        try
        {
            await EnsureParticipantAsync(
                userId,
                conversationId);

            await Groups.AddToGroupAsync(
                Context.ConnectionId,
                GetConversationGroupName(
                    conversationId));

            var readAtUtc =
                await _chatService
                    .MarkConversationAsReadAsync(
                        userId,
                        conversationId);

            await NotifyConversationReadAsync(
                conversationId,
                userId,
                readAtUtc);

            _logger.LogInformation(
                "User joined authorized chat conversation. "
                + "UserId: {UserId}, "
                + "ConversationId: {ConversationId}, "
                + "ConnectionId: {ConnectionId}.",
                userId,
                conversationId,
                Context.ConnectionId);
        }
        catch (ForbiddenException)
        {
            _logger.LogWarning(
                "Unauthorized chat group join rejected. "
                + "UserId: {UserId}, "
                + "ConversationId: {ConversationId}, "
                + "ConnectionId: {ConnectionId}.",
                userId,
                conversationId,
                Context.ConnectionId);

            throw;
        }
    }

    public async Task LeaveConversation(
        int conversationId)
    {
        var userId =
            GetCurrentUserId();

        await EnsureParticipantAsync(
            userId,
            conversationId);

        await Clients
            .OthersInGroup(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "TypingChanged",
                new
                {
                    conversationId,
                    userId,
                    isTyping = false
                });

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

        await EnsureParticipantAsync(
    userId,
    conversationId);

        if (!_messageRateLimiter.TryAcquire(
        userId,
        conversationId,
        out var retryAfter))
        {
            _logger.LogWarning(
                "Chat message rate limit exceeded. "
                + "UserId: {UserId}, "
                + "ConversationId: {ConversationId}, "
                + "ConnectionId: {ConnectionId}.",
                userId,
                conversationId,
                Context.ConnectionId);

            var retryAfterSeconds =
                Math.Max(
                    1,
                    (int)Math.Ceiling(
                        retryAfter.TotalSeconds));

            throw new HubException(
                $"Too many messages. Try again in "
                + $"{retryAfterSeconds} seconds.");
        }

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
                    result.ClientMessageId,

                IsRead =
                    false,

                ReadAtUtc =
                    null
            };

        await Clients
            .OthersInGroup(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "ReceiveMessage",
                recipientResult);

        await Clients
            .OthersInGroup(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "TypingChanged",
                new
                {
                    conversationId,
                    userId,
                    isTyping = false
                });
    }

    public async Task SetTyping(
        int conversationId,
        bool isTyping)
    {
        var userId =
            GetCurrentUserId();

        await EnsureParticipantAsync(
            userId,
            conversationId);

        await Clients
            .OthersInGroup(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "TypingChanged",
                new
                {
                    conversationId,
                    userId,
                    isTyping
                });
    }

    public async Task MarkAsRead(
        int conversationId)
    {
        var userId =
            GetCurrentUserId();

        await EnsureParticipantAsync(
            userId,
            conversationId);

        var readAtUtc =
            await _chatService
                .MarkConversationAsReadAsync(
                    userId,
                    conversationId);

        await NotifyConversationReadAsync(
            conversationId,
            userId,
            readAtUtc);
    }

    private async Task
        NotifyConversationReadAsync(
            int conversationId,
            int readerUserId,
            DateTime readAtUtc)
    {
        await Clients
            .OthersInGroup(
                GetConversationGroupName(
                    conversationId))
            .SendAsync(
                "ConversationRead",
                new
                {
                    conversationId,
                    readerUserId,
                    readAtUtc
                });
    }

    private async Task EnsureParticipantAsync(
        int userId,
        int conversationId)
    {
        var isParticipant =
            await _chatService
                .IsParticipantAsync(
                    userId,
                    conversationId);

        if (isParticipant)
        {
            return;
        }

        _logger.LogWarning(
            "Chat conversation access rejected. "
            + "UserId: {UserId}, "
            + "ConversationId: {ConversationId}, "
            + "ConnectionId: {ConnectionId}.",
            userId,
            conversationId,
            Context.ConnectionId);

        throw new ForbiddenException(
            "You are not allowed to access this conversation.");
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