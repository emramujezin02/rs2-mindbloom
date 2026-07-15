using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Chat.DTOs;
using MindBloom.Application.Features.Chat.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly IChatService
        _chatService;

    public ChatController(
        IChatService chatService)
    {
        _chatService =
            chatService;
    }

    [HttpPost(
        "appointments/{appointmentId}/conversation")]
    public async Task<IActionResult>
        GetOrCreateConversation(
            int appointmentId)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _chatService
                .GetOrCreateForAppointmentAsync(
                    userId,
                    appointmentId);

        return Ok(result);
    }

    [HttpGet(
        "conversations/{conversationId}/messages")]
    public async Task<IActionResult>
        GetMessages(
            int conversationId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 20)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _chatService
                .GetMessagesAsync(
                    userId,
                    conversationId,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }

    [HttpPost("messages")]
    public async Task<IActionResult>
        SendMessage(
            SendChatMessageDto request)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _chatService
                .SendMessageAsync(
                    userId,
                    request);

        return Ok(result);
    }

    [HttpPut(
        "conversations/{conversationId}/read")]
    public async Task<IActionResult>
        MarkAsRead(
            int conversationId)
    {
        var userId =
            GetCurrentUserId();

        await _chatService
            .MarkConversationAsReadAsync(
                userId,
                conversationId);

        return Ok(new
        {
            message =
                "Conversation marked as read."
        });
    }

    private int GetCurrentUserId()
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