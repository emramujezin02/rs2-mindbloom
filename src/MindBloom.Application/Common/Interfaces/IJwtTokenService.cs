using MindBloom.Domain.Entities;

namespace MindBloom.Application.Common.Interfaces;

public interface IJwtTokenService
{
    Task<string> GenerateTokenAsync(
        ApplicationUser user,
        IList<string> roles);
}