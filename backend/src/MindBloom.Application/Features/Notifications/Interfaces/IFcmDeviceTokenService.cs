using MindBloom.Application.Features.Notifications.DTOs;

namespace MindBloom.Application.Features.Notifications.Interfaces;

public interface IFcmDeviceTokenService
{
    Task RegisterAsync(
        int userId,
        RegisterFcmTokenDto request,
        CancellationToken cancellationToken =
            default);

    Task UnregisterAsync(
        int userId,
        UnregisterFcmTokenDto request,
        CancellationToken cancellationToken =
            default);
}