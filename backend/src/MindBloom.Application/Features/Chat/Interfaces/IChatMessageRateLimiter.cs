namespace MindBloom.Application.Features.Chat.Interfaces;

public interface IChatMessageRateLimiter
{
    bool TryAcquire(
        int userId,
        int conversationId,
        out TimeSpan retryAfter);
}