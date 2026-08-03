using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public class AdminAuditService
    : IAdminAuditService
{
    private readonly ApplicationDbContext
        _context;

    public AdminAuditService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<
        PagedResponse<AdminAuditLogDto>>
        GetAuditLogsAsync(
            SearchAdminAuditLogsDto request,
            CancellationToken cancellationToken =
                default)
    {
        var pagination =
            PaginationHelper.Normalize(
                request.PageNumber,
                request.PageSize);

        var query =
            _context.AdminAuditLogs
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted)
                .AsQueryable();

        if (request.AdminUserId.HasValue)
        {
            query = query.Where(x =>
                x.AdminUserId ==
                request.AdminUserId.Value);
        }

        if (!string.IsNullOrWhiteSpace(
                request.Action))
        {
            var action =
                request.Action.Trim();

            query = query.Where(x =>
                x.Action == action);
        }

        if (!string.IsNullOrWhiteSpace(
                request.EntityType))
        {
            var entityType =
                request.EntityType.Trim();

            query = query.Where(x =>
                x.EntityType == entityType);
        }

        if (request.FromUtc.HasValue)
        {
            query = query.Where(x =>
                x.OccurredAtUtc >=
                request.FromUtc.Value);
        }

        if (request.ToUtc.HasValue)
        {
            query = query.Where(x =>
                x.OccurredAtUtc <=
                request.ToUtc.Value);
        }

        if (request.IsSuccessful.HasValue)
        {
            query = query.Where(x =>
                x.IsSuccessful ==
                request.IsSuccessful.Value);
        }

        if (!string.IsNullOrWhiteSpace(
                request.Search))
        {
            var search =
                request.Search
                    .Trim()
                    .ToLower();

            query = query.Where(x =>
                x.AdminName
                    .ToLower()
                    .Contains(search)
                ||
                x.AdminEmail
                    .ToLower()
                    .Contains(search)
                ||
                x.Action
                    .ToLower()
                    .Contains(search)
                ||
                x.EntityType
                    .ToLower()
                    .Contains(search)
                ||
                (
                    x.EntityId ??
                    string.Empty
                )
                .ToLower()
                .Contains(search)
                ||
                x.CorrelationId
                    .ToLower()
                    .Contains(search));
        }

        var totalCount =
            await query.CountAsync(
                cancellationToken);

        var items =
            await query
                .OrderByDescending(x =>
                    x.OccurredAtUtc)
                .ThenByDescending(x =>
                    x.Id)
                .Skip(
                    pagination.Skip)
                .Take(
                    pagination.PageSize)
                .Select(x =>
                    new AdminAuditLogDto
                    {
                        Id = x.Id,

                        AdminUserId =
                            x.AdminUserId,

                        AdminName =
                            x.AdminName,

                        AdminEmail =
                            x.AdminEmail,

                        Action =
                            x.Action,

                        EntityType =
                            x.EntityType,

                        EntityId =
                            x.EntityId,

                        HttpMethod =
                            x.HttpMethod,

                        RequestPath =
                            x.RequestPath,

                        OccurredAtUtc =
                            x.OccurredAtUtc,

                        PreviousValues =
                            x.PreviousValues,

                        NewValues =
                            x.NewValues,

                        IpAddress =
                            x.IpAddress,

                        CorrelationId =
                            x.CorrelationId,

                        IsSuccessful =
                            x.IsSuccessful,

                        StatusCode =
                            x.StatusCode,

                        ResultMessage =
                            x.ResultMessage
                    })
                .ToListAsync(
                    cancellationToken);

        return PagedResponse<AdminAuditLogDto>
            .Create(
                items,
                pagination.PageNumber,
                pagination.PageSize,
                totalCount);
    }

    public async Task<
        AdminAuditFilterOptionsDto>
        GetFilterOptionsAsync(
            CancellationToken cancellationToken =
                default)
    {
        var users =
            await _context.AdminAuditLogs
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.AdminUserId.HasValue)
                .GroupBy(x => new
                {
                    Id =
                        x.AdminUserId!.Value,

                    x.AdminName,

                    x.AdminEmail
                })
                .Select(group =>
                    new AdminAuditUserOptionDto
                    {
                        Id =
                            group.Key.Id,

                        FullName =
                            group.Key.AdminName,

                        Email =
                            group.Key.AdminEmail
                    })
                .OrderBy(x =>
                    x.FullName)
                .ThenBy(x =>
                    x.Email)
                .ToListAsync(
                    cancellationToken);

        var actions =
            await _context.AdminAuditLogs
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.Action != string.Empty)
                .Select(x =>
                    x.Action)
                .Distinct()
                .OrderBy(x => x)
                .ToListAsync(
                    cancellationToken);

        var entityTypes =
            await _context.AdminAuditLogs
                .AsNoTracking()
                .Where(x =>
                    !x.IsDeleted &&
                    x.EntityType !=
                    string.Empty)
                .Select(x =>
                    x.EntityType)
                .Distinct()
                .OrderBy(x => x)
                .ToListAsync(
                    cancellationToken);

        return new AdminAuditFilterOptionsDto
        {
            Users = users,

            Actions = actions,

            EntityTypes = entityTypes
        };
    }

    public async Task WriteAsync(
        AdminAuditWriteDto request,
        CancellationToken cancellationToken =
            default)
    {
        var log =
            new AdminAuditLog
            {
                AdminUserId =
                    request.AdminUserId,

                AdminName =
                    Limit(
                        request.AdminName,
                        200),

                AdminEmail =
                    Limit(
                        request.AdminEmail,
                        256),

                Action =
                    Limit(
                        request.Action,
                        150),

                EntityType =
                    Limit(
                        request.EntityType,
                        150),

                EntityId =
                    LimitNullable(
                        request.EntityId,
                        100),

                HttpMethod =
                    Limit(
                        request.HttpMethod,
                        20),

                RequestPath =
                    Limit(
                        request.RequestPath,
                        1000),

                PreviousValues =
                    LimitNullable(
                        request.PreviousValues,
                        4000),

                NewValues =
                    LimitNullable(
                        request.NewValues,
                        4000),

                IpAddress =
                    LimitNullable(
                        request.IpAddress,
                        100),

                CorrelationId =
                    Limit(
                        request.CorrelationId,
                        100),

                IsSuccessful =
                    request.IsSuccessful,

                StatusCode =
                    request.StatusCode,

                ResultMessage =
                    LimitNullable(
                        request.ResultMessage,
                        1000),

                OccurredAtUtc =
                    request.OccurredAtUtc,

                CreatedAtUtc =
                    request.OccurredAtUtc
            };

        _context.AdminAuditLogs.Add(log);

        await _context.SaveChangesAsync(
            cancellationToken);
    }

    private static string Limit(
        string? value,
        int maximumLength)
    {
        var normalized =
            value?.Trim()
            ?? string.Empty;

        return normalized.Length <= maximumLength
            ? normalized
            : normalized[..maximumLength];
    }

    private static string? LimitNullable(
        string? value,
        int maximumLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized =
            value.Trim();

        return normalized.Length <= maximumLength
            ? normalized
            : normalized[..maximumLength];
    }
}