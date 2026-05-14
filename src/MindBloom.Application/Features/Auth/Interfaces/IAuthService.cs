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

}