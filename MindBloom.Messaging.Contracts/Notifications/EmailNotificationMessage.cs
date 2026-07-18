namespace MindBloom.Messaging.Contracts.Notifications;

public sealed record EmailNotificationMessage : NotificationMessage
{
    public required string RecipientEmail { get; init; }
    public string? RecipientName { get; init; }
    public required string Subject { get; init; }
    public string? Body { get; init; }
    public bool IsHtml { get; init; } = true;
    public string? TemplateName { get; init; }
    public Dictionary<string, string?> TemplateData { get; init; } = [];
    public string? ReplyToEmail { get; init; }
    public List<string> CcRecipients { get; init; } = [];
    public List<string> BccRecipients { get; init; } = [];
}