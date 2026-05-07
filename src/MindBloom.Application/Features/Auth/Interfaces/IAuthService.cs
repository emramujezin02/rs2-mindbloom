using MindBloom.Application.Features.Auth.DTOs;

namespace MindBloom.Application.Features.Auth.Interfaces;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request);

    Task<AuthResponse> RegisterAsync(RegisterRequest request);
}