using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Chat.DTOs;
using MindBloom.Application.Features.Chat.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class ChatService : IChatService
{
    private const int MaximumMessageLength =
        2000;

    private readonly ApplicationDbContext
        _context;

    public ChatService(
        ApplicationDbContext context)
    {
        _context = context;
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
                .Include(x => x.Conversation)
                    .ThenInclude(x => x.Participants)
                .FirstOrDefaultAsync(x =>
                    x.Id == appointmentId &&
                    !x.IsDeleted);

        if (appointment == null)
        {
            throw new Exception(
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
                /*
                 * Ako su dva zahtjeva istovremeno
                 * pokušala kreirati conversation,
                 * učitavamo već kreirani zapis.
                 */
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
                appointment.Conversation.Id,

            AppointmentId =
                appointment.Id,

            OtherParticipantName =
                otherParticipantName,

            IsClosed =
                appointment.Conversation.IsClosed,

            CreatedAtUtc =
                appointment.Conversation.CreatedAtUtc
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
        ValidatePaging(
            ref pageNumber,
            ref pageSize);

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

        /*
         * Najnovije poruke se uzimaju prve,
         * ali response se vraća hronološki
         * unutar trenutne stranice.
         */
        var messages =
            await query
                .OrderByDescending(x =>
                    x.SentAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    (pageNumber - 1) *
                    pageSize)
                .Take(pageSize)
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
                            x.IsEdited
                    })
                .ToListAsync();

        messages =
            messages
                .OrderBy(x => x.SentAtUtc)
                .ThenBy(x => x.Id)
                .ToList();

        return new PagedResponse<
            ChatMessageResponseDto>
        {
            Items =
                messages,

            PageNumber =
                pageNumber,

            PageSize =
                pageSize,

            TotalCount =
                totalCount,

            TotalPages =
                (int)Math.Ceiling(
                    totalCount /
                    (double)pageSize)
        };
    }

    public async Task<ChatMessageResponseDto>
        SendMessageAsync(
            int currentUserId,
            SendChatMessageDto request)
    {
        var content =
            request.Content?.Trim() ??
            string.Empty;

        if (string.IsNullOrWhiteSpace(
                content))
        {
            throw new Exception(
                "Message content is required.");
        }

        if (content.Length >
            MaximumMessageLength)
        {
            throw new Exception(
                $"Message may contain at most "
                + $"{MaximumMessageLength} characters.");
        }

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
            throw new Exception(
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
                    false
            };

        _context.ChatMessages.Add(
            message);

        participant.LastReadAtUtc =
            DateTime.UtcNow;

        await _context.SaveChangesAsync();

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
                true,

            IsEdited =
                message.IsEdited
        };
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

    private static void ValidatePaging(
        ref int pageNumber,
        ref int pageSize)
    {
        if (pageNumber < 1)
        {
            pageNumber = 1;
        }

        if (pageSize < 1)
        {
            pageSize = 20;
        }

        if (pageSize > 100)
        {
            pageSize = 100;
        }
    }
}