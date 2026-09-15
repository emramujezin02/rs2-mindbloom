using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace MindBloom.IntegrationTests.Infrastructure;

public sealed class TestAuthenticationHandler
    : AuthenticationHandler<
        AuthenticationSchemeOptions>
{
    public const string SchemeName =
        "IntegrationTest";

    public const string UserIdHeader =
        "X-Test-UserId";

    public const string RoleHeader =
        "X-Test-Role";

    public const string EmailHeader =
        "X-Test-Email";

    public TestAuthenticationHandler(
        IOptionsMonitor<
            AuthenticationSchemeOptions>
            options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(
            options,
            logger,
            encoder)
    {
    }

    protected override Task<
        AuthenticateResult>
        HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(
                UserIdHeader,
                out var userIdValue) ||
            string.IsNullOrWhiteSpace(
                userIdValue))
        {
            return Task.FromResult(
                AuthenticateResult
                    .NoResult());
        }

        var userId =
            userIdValue.ToString();

        var role =
            Request.Headers.TryGetValue(
                RoleHeader,
                out var roleValue)
                ? roleValue.ToString()
                : string.Empty;

        var email =
            Request.Headers.TryGetValue(
                EmailHeader,
                out var emailValue)
                ? emailValue.ToString()
                : $"integration-{userId}@mindbloom.test";

        var claims =
            new List<Claim>
            {
                new(
                    ClaimTypes.NameIdentifier,
                    userId),

                new(
                    ClaimTypes.Email,
                    email),

                new(
                    ClaimTypes.Name,
                    email)
            };

        if (!string.IsNullOrWhiteSpace(
                role))
        {
            claims.Add(
                new Claim(
                    ClaimTypes.Role,
                    role));
        }

        var identity =
            new ClaimsIdentity(
                claims,
                SchemeName);

        var principal =
            new ClaimsPrincipal(
                identity);

        var ticket =
            new AuthenticationTicket(
                principal,
                SchemeName);

        return Task.FromResult(
            AuthenticateResult.Success(
                ticket));
    }
}