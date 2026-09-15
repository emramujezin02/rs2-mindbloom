namespace MindBloom.Application.Features.Notifications.DTOs;

public sealed class UnregisterFcmTokenDto
{
    public required string Token { get; init; }
}