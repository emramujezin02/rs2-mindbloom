using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;

namespace MindBloom.SecurityTests.Infrastructure;

public sealed class TestJwtTokenService
    : IJwtTokenService
{
    public Task<string> GenerateTokenAsync(
        ApplicationUser user)
    {
        return Task.FromResult(
            $"security-test-access-token-{user.Id}");
    }

    public string GenerateRefreshToken()
    {
        return Convert.ToBase64String(
            Guid.NewGuid()
                .ToByteArray());
    }
}