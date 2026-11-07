using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Security;

public static class AccessTokenSessionValidator
{
    public static async Task ValidateAsync(TokenValidatedContext context)
    {
        var principal = context.Principal;
        var identifiers = principal?.FindAll(ClaimTypes.NameIdentifier).Select(claim => claim.Value).Distinct(StringComparer.Ordinal).ToArray() ?? [];
        var sessions = principal?.Claims.Where(claim => claim.Type is "sid" or ClaimTypes.Sid).ToArray() ?? [];
        if (identifiers.Length != 1 || !int.TryParse(identifiers[0], out var userId) || userId <= 0 ||
            sessions.Length != 1 || !Guid.TryParseExact(sessions[0].Value, "N", out _))
        {
            context.Fail("Invalid authenticated session.");
            return;
        }

        var db = context.HttpContext.RequestServices.GetRequiredService<ApplicationDbContext>();
        var sessionId = sessions[0].Value;
        var now = DateTime.UtcNow;
        // Rotation keeps the session alive through its unrevoked successor; a
        // historical, rotated row alone must never authorize an access token.
        var active = await db.RefreshTokens.AsNoTracking().AnyAsync(token =>
            token.UserId == userId && token.SessionId == sessionId && !token.IsDeleted &&
            token.RevokedAtUtc == null && token.IssuedAtUtc <= now && token.ExpiresAtUtc > now &&
            token.User.IsActive && !token.User.IsBlocked,
            context.HttpContext.RequestAborted);
        if (!active) context.Fail("User session is no longer valid.");
    }
}
