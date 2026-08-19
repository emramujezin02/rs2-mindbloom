using System.Net.Http;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Observability;

public sealed class CorrelationIdDelegatingHandler
    : DelegatingHandler
{
    private const string HeaderName =
        "X-Correlation-ID";

    private readonly ICorrelationIdAccessor
        _correlationIdAccessor;

    public CorrelationIdDelegatingHandler(
        ICorrelationIdAccessor correlationIdAccessor)
    {
        _correlationIdAccessor =
            correlationIdAccessor;
    }

    protected override Task<HttpResponseMessage>
        SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
    {
        var correlationId =
            _correlationIdAccessor
                .CorrelationId;

        if (!string.IsNullOrWhiteSpace(
                correlationId))
        {
            request.Headers.Remove(
                HeaderName);

            request.Headers.TryAddWithoutValidation(
                HeaderName,
                correlationId);
        }

        return base.SendAsync(
            request,
            cancellationToken);
    }
}