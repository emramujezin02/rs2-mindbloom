using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public sealed class NotificationsController
    : ControllerBase
{
    private readonly INotificationService
        _notificationService;

    public NotificationsController(
        INotificationService notificationService)
    {
        _notificationService =
            notificationService;
    }

    [HttpGet]
    public async Task<IActionResult>
        GetMyNotifications(
            [FromQuery]
            NotificationQueryDto query)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _notificationService
                .GetMyNotificationsAsync(
                    userId,
                    query);

        return Ok(result);
    }

    [HttpGet("unread-count")]
    public async Task<IActionResult>
        GetUnreadCount()
    {
        var userId =
            GetAuthenticatedUserId();

        var unreadCount =
            await _notificationService
                .GetUnreadCountAsync(
                    userId);

        return Ok(new
        {
            unreadCount
        });
    }

    [HttpPut("{notificationId:int}/read")]
    public async Task<IActionResult>
        MarkAsRead(
            int notificationId)
    {
        var userId =
            GetAuthenticatedUserId();

        await _notificationService
            .MarkAsReadAsync(
                userId,
                notificationId);

        return Ok(new
        {
            message =
                "Notification marked as read."
        });
    }

    [HttpPut("read-all")]
    public async Task<IActionResult>
        MarkAllAsRead()
    {
        var userId =
            GetAuthenticatedUserId();

        await _notificationService
            .MarkAllAsReadAsync(
                userId);

        return Ok(new
        {
            message =
                "All notifications marked as read."
        });
    }

    private int GetAuthenticatedUserId()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new UnauthorizedException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}