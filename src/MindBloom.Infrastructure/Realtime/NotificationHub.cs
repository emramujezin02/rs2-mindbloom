using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.Security.Claims;
using MindBloom.Shared.Observability;

namespace MindBloom.Infrastructure.Realtime;

[Authorize]
public sealed class NotificationHub : Hub
{
    private readonly ApplicationMetrics
    _metrics;

    private bool _connectionCounted;

    public NotificationHub(
    ApplicationMetrics metrics)
    {
        _metrics =
            metrics;
    }

    public override async Task OnConnectedAsync()
    {
        var userId =
            Context.User?
                .FindFirstValue(
                    ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            Context.Abort();

            return;
        }

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            GetUserGroupName(userId));

        _metrics
    .IncrementSignalRConnections();

        _connectionCounted =
            true;

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(
        Exception? exception)
    {
        var userId =
            Context.User?
                .FindFirstValue(
                    ClaimTypes.NameIdentifier);

        if (!string.IsNullOrWhiteSpace(userId))
        {
            await Groups.RemoveFromGroupAsync(
                Context.ConnectionId,
                GetUserGroupName(userId));
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

    private static string GetUserGroupName(
        string userId)
    {
        return $"user-{userId}";
    }
}