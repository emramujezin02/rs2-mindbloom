namespace MindBloom.Domain.Entities;

public sealed class ApiIdempotencyRecord
{
    public long Id { get; set; }

    public string IdempotencyKey { get; set; } =
        string.Empty;

    public int UserId { get; set; }

    public string Operation { get; set; } =
        string.Empty;

    public string RequestHash { get; set; } =
        string.Empty;

    public string Status { get; set; } =
        "Processing";

    public int? ResponseStatusCode
    {
        get;
        set;
    }

    public string? ResponseBody
    {
        get;
        set;
    }

    public DateTime CreatedAtUtc { get; set; } =
        DateTime.UtcNow;

    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? CompletedAtUtc
    {
        get;
        set;
    }
}