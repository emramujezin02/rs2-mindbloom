using System.Collections.Concurrent;
using Microsoft.Extensions.Configuration;
using MindBloom.Application.Features.Chat.Interfaces;

namespace MindBloom.Infrastructure.Services;

public sealed class ChatMessageRateLimiter
    : IChatMessageRateLimiter
{
    private readonly ConcurrentDictionary<
        ChatRateLimitKey,
        ChatRateLimitState>
        _states = new();

    private readonly int
        _maximumMessagesPerWindow;

    private readonly TimeSpan
        _window;

    public ChatMessageRateLimiter(
        IConfiguration configuration)
    {
        var permitLimit =
            configuration.GetValue<int>(
                "RateLimiting:ChatMessages:PermitLimit");

        var windowSeconds =
            configuration.GetValue<int>(
                "RateLimiting:ChatMessages:WindowSeconds");

        if (permitLimit <= 0)
        {
            throw new InvalidOperationException(
                "RateLimiting:ChatMessages:PermitLimit must be greater than zero.");
        }

        if (windowSeconds <= 0)
        {
            throw new InvalidOperationException(
                "RateLimiting:ChatMessages:WindowSeconds must be greater than zero.");
        }

        _maximumMessagesPerWindow =
            permitLimit;

        _window =
            TimeSpan.FromSeconds(
                windowSeconds);
    }

    public bool TryAcquire(
        int userId,
        int conversationId,
        out TimeSpan retryAfter)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "User identifier is invalid.",
                nameof(userId));
        }

        if (conversationId <= 0)
        {
            throw new ArgumentException(
                "Conversation identifier is invalid.",
                nameof(conversationId));
        }

        var now =
            DateTime.UtcNow;

        var key =
            new ChatRateLimitKey(
                userId,
                conversationId);

        var state =
            _states.GetOrAdd(
                key,
                _ =>
                    new ChatRateLimitState());

        lock (state.SyncRoot)
        {
            while (
                state.MessageTimestamps.Count >
                    0 &&
                now -
                    state.MessageTimestamps
                        .Peek() >=
                _window)
            {
                state.MessageTimestamps
                    .Dequeue();
            }

            if (state.MessageTimestamps.Count >=
                _maximumMessagesPerWindow)
            {
                var oldestTimestamp =
                    state.MessageTimestamps
                        .Peek();

                var availableAt =
                    oldestTimestamp +
                    _window;

                retryAfter =
                    availableAt > now
                        ? availableAt - now
                        : TimeSpan.Zero;

                return false;
            }

            state.MessageTimestamps
                .Enqueue(now);

            retryAfter =
                TimeSpan.Zero;

            return true;
        }
    }

    private readonly record struct
        ChatRateLimitKey(
            int UserId,
            int ConversationId);

    private sealed class ChatRateLimitState
    {
        public object SyncRoot { get; } =
            new();

        public Queue<DateTime>
            MessageTimestamps
        {
            get;
        } = new();
    }
}