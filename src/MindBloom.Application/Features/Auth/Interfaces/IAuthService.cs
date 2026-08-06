using MindBloom.Application.Features.Auth.DTOs;

namespace MindBloom.Application.Features.Auth.Interfaces;

public interface IAuthService
{
    Task<AuthResponseDto> LoginAsync(LoginRequestDto request);

    Task<AuthResponseDto> RegisterAsync(RegisterRequestDto request);

    Task ForgotPasswordAsync(ForgotPasswordDto request);

    Task ResetPasswordAsync(ResetPasswordDto request);

    Task ChangePasswordAsync(int userId,ChangePasswordDto request);
    
    Task SendVerificationEmailAsync(string email);

    Task VerifyEmailAsync(VerifyEmailDto request);
    Task LogoutAllAsync(
    int userId);

    Task<AuthResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request);

    Task DeleteAccountAsync(int userId,DeleteAccountRequestDto request);

    Task<Login2FAResponseDto> LoginWith2FAAsync(LoginRequestDto request);

    Task<AuthResponseDto> Verify2FAAsync(Verify2FADto request);

    Task Enable2FAAsync(int userId);

    Task Disable2FAAsync(int userId);

    Task LogoutAsync(
        int userId,
        string refreshToken);
    Task<bool> Is2FAEnabledAsync(int userId);

    Task SendEmailVerificationCodeAsync(string email);

    Task VerifyEmailCodeAsync(VerifyEmailCodeDto request);

    Task<RegisterTherapistResponseDto>
    RegisterTherapistAsync(
        RegisterTherapistRequestDto request);
}