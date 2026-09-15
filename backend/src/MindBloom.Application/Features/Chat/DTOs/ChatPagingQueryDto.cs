namespace MindBloom.Application.Features.Chat.DTOs;

public sealed class ChatPagingQueryDto
{
    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 20;
}