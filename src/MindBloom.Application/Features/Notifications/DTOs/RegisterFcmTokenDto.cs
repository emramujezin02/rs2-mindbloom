namespace MindBloom.Application.Features.Notifications.DTOs;

public sealed class RegisterFcmTokenDto
{
    public required string Token { get; init; }

    public required string Platform { get; init; }

    public string? DeviceId { get; init; }
}