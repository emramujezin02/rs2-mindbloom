using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Notifications.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
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
        GetMyNotifications()
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _notificationService
                .GetMyNotificationsAsync(
                    userId);

        return Ok(result);
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

    private int GetAuthenticatedUserId()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}