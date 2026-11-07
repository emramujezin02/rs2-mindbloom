using MindBloom.Application.Features.Auth.DTOs;

namespace MindBloom.Infrastructure.Security;

internal enum AuthRefreshRejection { Reused, Expired, UserUnavailable }

// An expected rejection is data inside the transaction. It becomes an exception
// only after the guard confirms commit. Arbitrary exceptions never request commit.
internal sealed class AuthRefreshOutcome
{
    private readonly AuthResponseDto? _response;
    private readonly AuthRefreshRejection? _rejection;
    private AuthRefreshOutcome(AuthResponseDto? response, AuthRefreshRejection? rejection)
    {
        _response = response;
        _rejection = rejection;
    }
    public static AuthRefreshOutcome Accepted(AuthResponseDto response) => new(response ?? throw new ArgumentNullException(nameof(response)), null);
    public static AuthRefreshOutcome Rejected(AuthRefreshRejection rejection) => rejection switch
    {
        AuthRefreshRejection.Reused or AuthRefreshRejection.Expired or AuthRefreshRejection.UserUnavailable => new(null, rejection),
        _ => throw new ArgumentOutOfRangeException(nameof(rejection))
    };
    public AuthResponseDto GetResponse() => _rejection switch
    {
        AuthRefreshRejection.Reused => throw new UnauthorizedAccessException("Refresh token reuse detected."),
        AuthRefreshRejection.Expired => throw new UnauthorizedAccessException("Refresh token expired."),
        AuthRefreshRejection.UserUnavailable => throw new UnauthorizedAccessException("User session is no longer valid."),
        null when _response != null => _response,
        _ => throw new InvalidOperationException("Invalid refresh outcome.")
    };
}
