using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Chat.DTOs;
using MindBloom.Application.Features.Chat.Interfaces;
using MindBloom.Shared.Observability;

namespace MindBloom.Infrastructure.Realtime;

[Authorize]
public sealed class ChatHub : Hub
{
    private static readonly EventId
    ConnectionEstablishedEvent =
        new(
            3400,
            "ChatConnectionEstablished");

    private static readonly EventId
        ConnectionRejectedEvent =
            new(
                3401,
                "ChatConnectionRejected");

    private static readonly EventId
        ConnectionDisconnectedEvent =
            new(
                3402,
                "ChatConnectionDisconnected");

    private static readonly EventId
        ConnectionDisconnectedUnexpectedlyEvent =
            new(
                3403,
                "ChatConnectionDisconnectedUnexpectedly");

    private static readonly EventId
        ConversationJoinedEvent =
            new(
                3410,
                "ChatConversationJoined");

    private static readonly EventId
        MessageRateLimitExceededEvent =
            new(
                3411,
                "ChatMessageRateLimitExceeded");

    private static readonly EventId
        ConversationAccessRejectedEvent =
            new(
                3412,
                "ChatConversationAccessRejected");

    private readonly IChatService
        _chatService;

    private readonly IValidator<SendChatMessageDto>
        _messageValidator;
    private readonly ILogger<ChatHub>
    _logger;
    private readonly IChatMessageRateLimiter
    _messageRateLimiter;

    private readonly ApplicationMetrics
    _metrics;

    private bool _connectionCounted;

    public ChatHub(
        IChatService chatService,
        IValidator<SendChatMessageDto>
            messageValidator,
        IChatMessageRateLimiter
            messageRateLimiter,
ILogger<ChatHub> logger,
ApplicationMetrics metrics)
    {
        _chatService =
            chatService;

        _messageValidator =
            messageValidator;

        _messageRateLimiter =
            messageRateLimiter;

        _logger =
            logger;

        _metrics =
    metrics;
    }

    public override async Task OnConnectedAsync()
    {
        try
        {
            var userId =
                GetCurrentUserId();

            using var logScope =
                BeginChatLogScope(
                    userId);

            _logger.LogInformation(
                ConnectionEstablishedEvent,
                "Authenticated chat connection established.");

            await base.OnConnectedAsync();

            _metrics
    .IncrementSignalRConnections();

            _connectionCounted =
                true;
        }
        catch (Exception exception)
        {
            using var logScope =
                BeginChatLogScope();

            _logger.LogWarning(
                ConnectionRejectedEvent,
                "Chat connection rejected because the authenticated user identity could not be resolved. FailureType: {FailureType}.",
                exception.GetType().Name);

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
            using var logScope =
    BeginChatLogScope(
        userId);

            if (exception == null)
            {
                _logger.LogInformation(
                    ConnectionDisconnectedEvent,
                    "Chat connection disconnected.");
            }
            else
            {
                _logger.LogWarning(
                    ConnectionDisconnectedUnexpectedlyEvent,
                    "Chat connection disconnected unexpectedly. FailureType: {FailureType}.",
                    exception.GetType().Name);
            }
        }

        if (_connectionCounted)
        {
            _metrics
                .DecrementSignalRConnections();

            _connectionCounted =
                false;
        }

        await base.OnDisconnectedAsync(
            exception);
    }


    public async Task JoinConversation(
    int conversationId)
    {
        var userId =
            GetCurrentUserId();

        using var logScope =
            BeginChatLogScope(
                userId);

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
            ConversationJoinedEvent,
            "User joined authorized chat conversation. ConversationId: {ConversationId}.",
            conversationId);
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

        using var logScope =
    BeginChatLogScope(
        userId);

        await EnsureParticipantAsync(
    userId,
    conversationId);

        if (!_messageRateLimiter.TryAcquire(
                userId,
                conversationId,
                out var retryAfter))
        {
            var retryAfterSeconds =
                Math.Max(
                    1,
                    (int)Math.Ceiling(
                        retryAfter.TotalSeconds));

            _logger.LogWarning(
                MessageRateLimitExceededEvent,
                "Chat message rate limit exceeded. ConversationId: {ConversationId}, RetryAfterSeconds: {RetryAfterSeconds}.",
                conversationId,
                retryAfterSeconds);

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

        using var logScope =
            BeginChatLogScope(
                userId);

        _logger.LogWarning(
            ConversationAccessRejectedEvent,
            "Chat conversation access rejected. ConversationId: {ConversationId}.",
            conversationId);

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

    private IDisposable? BeginChatLogScope(
    int? userId = null)
    {
        var httpContext =
            Context.GetHttpContext();

        var correlationId =
            httpContext?.TraceIdentifier;

        return _logger.BeginScope(
            new Dictionary<string, object?>
            {
                ["CorrelationId"] =
                    string.IsNullOrWhiteSpace(
                        correlationId)
                        ? Context.ConnectionId
                        : correlationId,

                ["UserId"] =
                    userId?.ToString()
                    ?? "anonymous",

                ["ConnectionId"] =
                    Context.ConnectionId,

                ["Module"] =
                    "ChatRealtime"
            });
    }

    private static string
        GetConversationGroupName(
            int conversationId)
    {
        return $"conversation-{conversationId}";
    }
}