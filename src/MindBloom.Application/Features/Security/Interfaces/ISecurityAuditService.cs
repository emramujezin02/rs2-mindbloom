using MindBloom.Application.Features.Security.DTOs;

namespace MindBloom.Application.Features.Security.Interfaces;

public interface ISecurityAuditService
{
    Task WriteAsync(
        SecurityAuditWriteDto request,
        CancellationToken cancellationToken =
            default);
}