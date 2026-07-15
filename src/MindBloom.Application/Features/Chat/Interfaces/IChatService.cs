using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Chat.DTOs;

namespace MindBloom.Application.Features.Chat.Interfaces;

public interface IChatService
{
    Task<ConversationResponseDto>
        GetOrCreateForAppointmentAsync(
            int currentUserId,
            int appointmentId);

    Task<PagedResponse<ChatMessageResponseDto>>
        GetMessagesAsync(
            int currentUserId,
            int conversationId,
            int pageNumber,
            int pageSize);

    Task<ChatMessageResponseDto>
        SendMessageAsync(
            int currentUserId,
            SendChatMessageDto request);

    Task MarkConversationAsReadAsync(
        int currentUserId,
        int conversationId);

    Task<bool> IsParticipantAsync(
        int currentUserId,
        int conversationId);

    Task<List<ConversationListItemDto>>
    GetMyConversationsAsync(
        int currentUserId);
}