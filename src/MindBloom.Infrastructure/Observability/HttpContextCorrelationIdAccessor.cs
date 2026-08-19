using Microsoft.AspNetCore.Http;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Observability;

public sealed class HttpContextCorrelationIdAccessor
    : ICorrelationIdAccessor
{
    private readonly IHttpContextAccessor
        _httpContextAccessor;

    public HttpContextCorrelationIdAccessor(
        IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor =
            httpContextAccessor;
    }

    public string? CorrelationId
    {
        get
        {
            var correlationId =
                _httpContextAccessor
                    .HttpContext?
                    .TraceIdentifier;

            return string.IsNullOrWhiteSpace(
                    correlationId)
                ? null
                : correlationId;
        }
    }
}