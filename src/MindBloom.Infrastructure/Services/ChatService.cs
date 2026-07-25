using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Chat.DTOs;
using MindBloom.Application.Features.Chat.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Services;

public sealed class ChatService : IChatService
{
    private readonly ApplicationDbContext
        _context;
    private readonly IBusinessNotificationService
    _businessNotificationService;

    public ChatService(
        ApplicationDbContext context,
        IBusinessNotificationService
            businessNotificationService)
    {
        _context = context;

        _businessNotificationService =
            businessNotificationService;
    }

    public async Task<List<ConversationListItemDto>>
    GetMyConversationsAsync(
        int currentUserId)
    {
        var conversations =
            await _context.Conversations
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.Participants.Any(
                        participant =>
                            participant.UserId ==
                                currentUserId &&
                            participant.IsActive &&
                            !participant.IsDeleted))
                .Select(x =>
                    new
                    {
                        Conversation =
                            x,

                        OtherParticipant =
                            x.Participants
                                .Where(participant =>
                                    participant.UserId !=
                                        currentUserId &&
                                    participant.IsActive &&
                                    !participant.IsDeleted)
                                .Select(participant =>
                                    new
                                    {
                                        participant.User
                                            .FirstName,

                                        participant.User
                                            .LastName
                                    })
                                .FirstOrDefault(),

                        CurrentParticipant =
                            x.Participants
                                .Where(participant =>
                                    participant.UserId ==
                                        currentUserId &&
                                    participant.IsActive &&
                                    !participant.IsDeleted)
                                .Select(participant =>
                                    new
                                    {
                                        participant
                                            .LastReadAtUtc
                                    })
                                .FirstOrDefault(),

                        LastMessage =
                            x.Messages
                                .Where(message =>
                                    !message.IsDeleted)
                                .OrderByDescending(message =>
                                    message.SentAtUtc)
                                .ThenByDescending(message =>
                                    message.Id)
                                .Select(message =>
                                    new
                                    {
                                        message.Content,

                                        message.SentAtUtc
                                    })
                                .FirstOrDefault(),

                        UnreadCount =
                            x.Messages.Count(message =>
                                !message.IsDeleted &&
                                message.SenderUserId !=
                                    currentUserId &&
                                (
                                    x.Participants
                                        .Where(participant =>
                                            participant.UserId ==
                                                currentUserId &&
                                            participant.IsActive &&
                                            !participant.IsDeleted)
                                        .Select(participant =>
                                            participant.LastReadAtUtc)
                                        .FirstOrDefault() ==
                                        null ||

                                    message.SentAtUtc >
                                    x.Participants
                                        .Where(participant =>
                                            participant.UserId ==
                                                currentUserId &&
                                            participant.IsActive &&
                                            !participant.IsDeleted)
                                        .Select(participant =>
                                            participant.LastReadAtUtc)
                                        .FirstOrDefault()
                                ))
                    })
                .OrderByDescending(x =>
                    x.LastMessage != null
                        ? x.LastMessage.SentAtUtc
                        : x.Conversation.CreatedAtUtc)
                .ToListAsync();

        return conversations
            .Select(x =>
                new ConversationListItemDto
                {
                    Id =
                        x.Conversation.Id,

                    AppointmentId =
                        x.Conversation.AppointmentId,

                    OtherParticipantName =
                        x.OtherParticipant == null
                            ? "Conversation participant"
                            : x.OtherParticipant.FirstName
                              + " "
                              + x.OtherParticipant.LastName,

                    LastMessage =
                        x.LastMessage?.Content,

                    LastMessageAtUtc =
                        x.LastMessage?.SentAtUtc,

                    UnreadCount =
                        x.UnreadCount,

                    IsClosed =
                        x.Conversation.IsClosed
                })
            .ToList();
    }

    public async Task<ConversationResponseDto>
        GetOrCreateForAppointmentAsync(
            int currentUserId,
            int appointmentId)
    {
        var appointment =
            await _context.Appointments
                .Include(x => x.Client)
                    .ThenInclude(x => x.User)
                .Include(x => x.Therapist)
                    .ThenInclude(x => x.User)
                .Include(x => x.Conversation!)
                    .ThenInclude(x => x.Participants)
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId &&
                    !x.IsDeleted);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        ValidateAppointmentParticipant(
            appointment,
            currentUserId);

        ValidateChatAvailability(
            appointment);

        if (appointment.Conversation == null)
        {
            var conversation =
                new Conversation
                {
                    AppointmentId =
                        appointment.Id,

                    IsClosed =
                        false
                };

            conversation.Participants.Add(
                new ConversationParticipant
                {
                    UserId =
                        appointment.Client.UserId,

                    JoinedAtUtc =
                        DateTime.UtcNow,

                    IsActive =
                        true
                });

            conversation.Participants.Add(
                new ConversationParticipant
                {
                    UserId =
                        appointment.Therapist.UserId,

                    JoinedAtUtc =
                        DateTime.UtcNow,

                    IsActive =
                        true
                });

            _context.Conversations.Add(
                conversation);

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                _context.ChangeTracker.Clear();

                conversation =
                    await _context.Conversations
                        .Include(x => x.Participants)
                        .FirstAsync(x =>
                            x.AppointmentId ==
                                appointmentId &&
                            !x.IsDeleted);
            }

            appointment.Conversation =
                conversation;
        }

        var resolvedConversation =
    appointment.Conversation
    ?? throw new NotFoundException(
        "Conversation could not be created.");

        var otherParticipantName =
            currentUserId ==
                appointment.Client.UserId
                ? appointment.Therapist.User.FirstName
                  + " "
                  + appointment.Therapist.User.LastName
                : appointment.Client.User.FirstName
                  + " "
                  + appointment.Client.User.LastName;

        return new ConversationResponseDto
        {
            Id =
                resolvedConversation.Id,

            AppointmentId =
                appointment.Id,

            OtherParticipantName =
                otherParticipantName,

            IsClosed =
                resolvedConversation.IsClosed,

            CreatedAtUtc =
                resolvedConversation.CreatedAtUtc
        };
    }

    public async Task<
        PagedResponse<ChatMessageResponseDto>>
        GetMessagesAsync(
            int currentUserId,
            int conversationId,
            int pageNumber,
            int pageSize)
    {
        var pagination =
    PaginationHelper.Normalize(
        pageNumber,
        pageSize);


        await EnsureParticipantAsync(
            currentUserId,
            conversationId);

        var query =
            _context.ChatMessages
                .AsNoTracking()
                .Include(x => x.SenderUser)
                .Where(x =>
                    x.ConversationId ==
                        conversationId &&
                    !x.IsDeleted);

        var totalCount =
            await query.CountAsync();

        var messages =
            await query
                .OrderByDescending(x =>
                    x.SentAtUtc)
                .ThenByDescending(x =>
                    x.Id)
.Skip(
    pagination.Skip)
.Take(
    pagination.PageSize)
                .Select(x =>
                    new ChatMessageResponseDto
                    {
                        Id =
                            x.Id,

                        ConversationId =
                            x.ConversationId,

                        SenderUserId =
                            x.SenderUserId,

                        SenderName =
                            x.SenderUser.FirstName
                            + " "
                            + x.SenderUser.LastName,

                        Content =
                            x.Content,

                        SentAtUtc =
                            x.SentAtUtc,

                        IsMine =
                            x.SenderUserId ==
                            currentUserId,

                        IsEdited =
                            x.IsEdited,

                        ClientMessageId =
    x.ClientMessageId,
                    })
                .ToListAsync();

        messages =
            messages
                .OrderBy(x => x.SentAtUtc)
                .ThenBy(x => x.Id)
                .ToList();

        return PagedResponse<ChatMessageResponseDto>
            .Create(
                messages,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<ChatMessageResponseDto>
    SendMessageAsync(
        int currentUserId,
        SendChatMessageDto request)
    {
        var content =
            request.Content.Trim();

        var clientMessageId =
            request.ClientMessageId.Trim();

        var conversation =
            await _context.Conversations
                .Include(x => x.Participants)
                .Include(x => x.Appointment)
                    .ThenInclude(x => x.Client)
                        .ThenInclude(x => x.User)
                .Include(x => x.Appointment)
                    .ThenInclude(x => x.Therapist)
                        .ThenInclude(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        request.ConversationId &&
                    !x.IsDeleted);

        if (conversation == null)
        {
            throw new NotFoundException(
                "Conversation not found.");
        }

        var participant =
            conversation.Participants
                .FirstOrDefault(x =>
                    x.UserId ==
                        currentUserId &&
                    x.IsActive &&
                    !x.IsDeleted);

        if (participant == null)
        {
            throw new UnauthorizedAccessException(
                "You are not a participant in this conversation.");
        }

        if (conversation.IsClosed)
        {
            throw new Exception(
                "This conversation is closed.");
        }

        ValidateChatAvailability(
            conversation.Appointment);

        var sender =
            currentUserId ==
                conversation.Appointment
                    .Client.UserId
                ? conversation.Appointment
                    .Client.User
                : conversation.Appointment
                    .Therapist.User;

        var existingMessage =
            await _context.ChatMessages
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.ConversationId ==
                        conversation.Id &&
                    x.ClientMessageId ==
                        clientMessageId &&
                    !x.IsDeleted);

        if (existingMessage != null)
        {
            return MapMessage(
                existingMessage,
                sender,
                currentUserId);
        }

        var message =
            new ChatMessage
            {
                ConversationId =
                    conversation.Id,

                SenderUserId =
                    currentUserId,

                Content =
                    content,

                SentAtUtc =
                    DateTime.UtcNow,

                IsEdited =
                    false,

                ClientMessageId =
                    clientMessageId
            };

        _context.ChatMessages.Add(
            message);

        participant.LastReadAtUtc =
            DateTime.UtcNow;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            _context.ChangeTracker.Clear();

            existingMessage =
                await _context.ChatMessages
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x =>
                        x.ConversationId ==
                            conversation.Id &&
                        x.ClientMessageId ==
                            clientMessageId &&
                        !x.IsDeleted);

            if (existingMessage == null)
            {
                throw;
            }

            return MapMessage(
                existingMessage,
                sender,
                currentUserId);
        }

        var recipientUserId =
            conversation.Participants
                .Where(participant =>
                    participant.UserId !=
                        currentUserId &&
                    participant.IsActive &&
                    !participant.IsDeleted)
                .Select(participant =>
                    participant.UserId)
                .FirstOrDefault();

        if (recipientUserId > 0)
        {
            await _businessNotificationService
                .PublishAsync(
                    recipientUserId,
                    "New chat message",
                    $"{sender.FirstName} "
                    + $"{sender.LastName} "
                    + "sent you a message.",
                    conversation.AppointmentId,
                    NotificationActionType.Chat);
        }

        return MapMessage(
            message,
            sender,
            currentUserId);
    }

    public async Task MarkConversationAsReadAsync(
        int currentUserId,
        int conversationId)
    {
        var participant =
            await _context
                .ConversationParticipants
                .FirstOrDefaultAsync(x =>
                    x.ConversationId ==
                        conversationId &&
                    x.UserId ==
                        currentUserId &&
                    x.IsActive &&
                    !x.IsDeleted);

        if (participant == null)
        {
            throw new UnauthorizedAccessException(
                "You are not a participant in this conversation.");
        }

        participant.LastReadAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    public async Task<bool> IsParticipantAsync(
        int currentUserId,
        int conversationId)
    {
        return await _context
            .ConversationParticipants
            .AnyAsync(x =>
                x.ConversationId ==
                    conversationId &&
                x.UserId ==
                    currentUserId &&
                x.IsActive &&
                !x.IsDeleted);
    }

    private async Task EnsureParticipantAsync(
        int currentUserId,
        int conversationId)
    {
        var isParticipant =
            await IsParticipantAsync(
                currentUserId,
                conversationId);

        if (!isParticipant)
        {
            throw new UnauthorizedAccessException(
                "You are not a participant in this conversation.");
        }
    }

    private static void
        ValidateAppointmentParticipant(
            Appointment appointment,
            int currentUserId)
    {
        var isClient =
            appointment.Client.UserId ==
            currentUserId;

        var isTherapist =
            appointment.Therapist.UserId ==
            currentUserId;

        if (!isClient &&
            !isTherapist)
        {
            throw new UnauthorizedAccessException(
                "You cannot access another user's appointment conversation.");
        }
    }

    private static void ValidateChatAvailability(
        Appointment appointment)
    {
        if (appointment.Status !=
                AppointmentStatus.Accepted &&
            appointment.Status !=
                AppointmentStatus.Completed)
        {
            throw new Exception(
                "Chat is available only for accepted or completed appointments.");
        }
    }

    private static ChatMessageResponseDto
    MapMessage(
        ChatMessage message,
        ApplicationUser sender,
        int currentUserId)
    {
        return new ChatMessageResponseDto
        {
            Id =
                message.Id,

            ConversationId =
                message.ConversationId,

            SenderUserId =
                message.SenderUserId,

            SenderName =
                sender.FirstName
                + " "
                + sender.LastName,

            Content =
                message.Content,

            SentAtUtc =
                message.SentAtUtc,

            IsMine =
                message.SenderUserId ==
                currentUserId,

            IsEdited =
                message.IsEdited,

            ClientMessageId =
                message.ClientMessageId
        };
    }

}