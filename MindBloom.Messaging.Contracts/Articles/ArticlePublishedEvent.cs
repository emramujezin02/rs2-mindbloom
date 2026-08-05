using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Articles;

public sealed record ArticlePublishedEvent
    : IntegrationEvent
{
    public int ArticleId { get; init; }

    public int AuthorUserId { get; init; }

    public string AuthorName { get; init; } =
        string.Empty;

    public string Title { get; init; } =
        string.Empty;

    public string Description { get; init; } =
        string.Empty;

    public int ArticleCategoryId { get; init; }

    public string CategoryName { get; init; } =
        string.Empty;

    public DateTime PublishedAtUtc { get; init; }
}