using MindBloom.Application.Features.Auth.DTOs;

namespace MindBloom.Application.Features.Auth.Interfaces;

public interface IAuthService
{
    Task<AuthResponseDto> LoginAsync(LoginRequestDto request);

    Task<AuthResponseDto> RegisterAsync(RegisterRequestDto request);
}