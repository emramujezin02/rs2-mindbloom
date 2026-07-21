namespace MindBloom.API.Models;

public sealed class ValidationErrorResponse
{
    public string Message { get; init; } =
        "One or more validation errors occurred.";

    public IDictionary<string, string[]> Errors { get; init; } =
        new Dictionary<string, string[]>();
}