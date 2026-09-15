using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Services;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(
        IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public int UserId
    {
        get
        {
            var userId = _httpContextAccessor
                .HttpContext?
                .User?
                .FindFirstValue(ClaimTypes.NameIdentifier);

            return string.IsNullOrWhiteSpace(userId)
                ? 0
                : int.Parse(userId);
        }
    }

    public string Username =>
        _httpContextAccessor
            .HttpContext?
            .User?
            .Identity?
            .Name ?? string.Empty;

    public bool IsAuthenticated =>
        _httpContextAccessor
            .HttpContext?
            .User?
            .Identity?
            .IsAuthenticated ?? false;
}