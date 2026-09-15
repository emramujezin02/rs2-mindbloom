using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using System.Security.Cryptography;

namespace MindBloom.Infrastructure.Security;

public class JwtTokenService : IJwtTokenService
{
    private readonly JwtSettings _jwtSettings;
    private readonly UserManager<ApplicationUser> _userManager;

    public JwtTokenService(IOptions<JwtSettings> jwtSettings, UserManager<ApplicationUser> userManager)
    {
        _jwtSettings = jwtSettings.Value;
        _userManager = userManager;
    }

    public async Task<string>
      GenerateTokenAsync(
          ApplicationUser user)
    {
        ArgumentNullException.ThrowIfNull(
            user);

        if (user.Id <= 0)
        {
            throw new InvalidOperationException(
                "JWT cannot be generated for "
                + "an invalid user.");
        }

        var roles =
            await _userManager
                .GetRolesAsync(user);

        if (roles.Count == 0)
        {
            throw new InvalidOperationException(
                "JWT cannot be generated for "
                + "a user without a role.");
        }

        var now =
            DateTime.UtcNow;

        var claims =
            new List<Claim>
            {
            new(
                JwtRegisteredClaimNames.Sub,
                user.Id.ToString()),

            new(
                ClaimTypes.NameIdentifier,
                user.Id.ToString()),

            new(
                ClaimTypes.Name,
                user.UserName
                ?? user.Id.ToString()),

            new(
                JwtRegisteredClaimNames.Jti,
                Guid.NewGuid()
                    .ToString("N"))
            };

        if (!string.IsNullOrWhiteSpace(
                user.Email))
        {
            claims.Add(
                new Claim(
                    ClaimTypes.Email,
                    user.Email));
        }

        claims.AddRange(
            roles.Select(
                role =>
                    new Claim(
                        ClaimTypes.Role,
                        role)));

        var key =
            new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(
                    _jwtSettings.SecretKey));

        var credentials =
            new SigningCredentials(
                key,
                SecurityAlgorithms.HmacSha256);

        var token =
            new JwtSecurityToken(
                issuer:
                    _jwtSettings.Issuer,

                audience:
                    _jwtSettings.Audience,

                claims:
                    claims,

                notBefore:
                    now,

                expires:
                    now.AddMinutes(
                        _jwtSettings
                            .ExpirationInMinutes),

                signingCredentials:
                    credentials);

        return new JwtSecurityTokenHandler()
            .WriteToken(token);
    }

    public string GenerateRefreshToken()
    {
        var randomBytes =
            RandomNumberGenerator
                .GetBytes(64);

        return Convert.ToBase64String(
            randomBytes);
    }
}