using System.Collections.Concurrent;
using MindBloom.Application.Features.Chat.Interfaces;
using MindBloom.Application.Features.Chat.Validators;

namespace MindBloom.Infrastructure.Services;

public sealed class ChatMessageRateLimiter
    : IChatMessageRateLimiter
{
    private readonly ConcurrentDictionary<
        ChatRateLimitKey,
        ChatRateLimitState>
        _states = new();

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

        var window =
            TimeSpan.FromSeconds(
                ChatValidationRules
                    .MessageRateLimitWindowSeconds);

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
                state.MessageTimestamps.Count > 0 &&
                now -
                state.MessageTimestamps.Peek() >=
                window)
            {
                state.MessageTimestamps
                    .Dequeue();
            }

            if (state.MessageTimestamps.Count >=
                ChatValidationRules
                    .MaximumMessagesPerWindow)
            {
                var oldestTimestamp =
                    state.MessageTimestamps
                        .Peek();

                var availableAt =
                    oldestTimestamp +
                    window;

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