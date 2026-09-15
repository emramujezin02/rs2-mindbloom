using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace MindBloom.SecurityTests.Infrastructure;

public static class TestJwtTokenFactory
{
    public static string CreateValidToken(
        int userId,
        string role)
    {
        return CreateToken(
            userId,
            role,
            DateTime.UtcNow.AddMinutes(
                10),
            MindBloomWebApplicationFactory
                .TestJwtSecret);
    }

    public static string CreateExpiredToken(
        int userId,
        string role)
    {
        return CreateToken(
            userId,
            role,
            DateTime.UtcNow.AddMinutes(
                -5),
            MindBloomWebApplicationFactory
                .TestJwtSecret,
            notBeforeUtc:
                DateTime.UtcNow.AddMinutes(
                    -20));
    }

    public static string CreateTokenWithInvalidSignature(
        int userId,
        string role)
    {
        const string wrongSecret =
            "MindBloom.SecurityTests.WRONG.JWT.Secret.That.Must.Never.Validate!";

        return CreateToken(
            userId,
            role,
            DateTime.UtcNow.AddMinutes(
                10),
            wrongSecret);
    }

    private static string CreateToken(
        int userId,
        string role,
        DateTime expiresUtc,
        string signingSecret,
        DateTime? notBeforeUtc = null)
    {
        var now =
            DateTime.UtcNow;

        var claims =
            new List<Claim>
            {
                new(
                    JwtRegisteredClaimNames.Sub,
                    userId.ToString()),

                new(
                    ClaimTypes.NameIdentifier,
                    userId.ToString()),

                new(
                    ClaimTypes.Name,
                    $"security-test-{userId}"),

                new(
                    ClaimTypes.Role,
                    role),

                new(
                    JwtRegisteredClaimNames.Jti,
                    Guid.NewGuid()
                        .ToString("N"))
            };

        var key =
            new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(
                    signingSecret));

        var credentials =
            new SigningCredentials(
                key,
                SecurityAlgorithms.HmacSha256);

        var token =
            new JwtSecurityToken(
                issuer:
                    MindBloomWebApplicationFactory
                        .TestJwtIssuer,

                audience:
                    MindBloomWebApplicationFactory
                        .TestJwtAudience,

                claims:
                    claims,

                notBefore:
                    notBeforeUtc ?? now,

                expires:
                    expiresUtc,

                signingCredentials:
                    credentials);

        return new JwtSecurityTokenHandler()
            .WriteToken(
                token);
    }
}