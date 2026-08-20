using Microsoft.AspNetCore.Mvc;

namespace MindBloom.API.Idempotency;

[AttributeUsage(
    AttributeTargets.Method,
    AllowMultiple = false,
    Inherited = true)]
public sealed class RequireIdempotencyAttribute
    : TypeFilterAttribute
{
    public RequireIdempotencyAttribute()
        : base(
            typeof(IdempotencyActionFilter))
    {
    }
}