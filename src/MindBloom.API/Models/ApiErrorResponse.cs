namespace MindBloom.API.Models;

public sealed class ApiErrorResponse
{
    public int StatusCode { get; init; }

    public string Title { get; init; } =
        string.Empty;

    public string Detail { get; init; } =
        string.Empty;

    public string TraceId { get; init; } =
        string.Empty;

    public IDictionary<string, string[]>?
        ValidationErrors
    { get; init; }

    public string? ExceptionType { get; init; }

    public string? StackTrace { get; init; }
}