using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Admin.DTOs;

namespace MindBloom.Application.Features.Admin.Interfaces;

public interface IAdminAuditService
{
    Task<PagedResponse<AdminAuditLogDto>>
        GetAuditLogsAsync(
            SearchAdminAuditLogsDto request,
            CancellationToken cancellationToken =
                default);

    Task<AdminAuditFilterOptionsDto>
        GetFilterOptionsAsync(
            CancellationToken cancellationToken =
                default);

    Task WriteAsync(
        AdminAuditWriteDto request,
        CancellationToken cancellationToken =
            default);

    Task<PagedResponse<SecurityAuditLogDto>>
    GetSecurityAuditLogsAsync(
        SearchSecurityAuditLogsDto request,
        CancellationToken cancellationToken =
            default);
}