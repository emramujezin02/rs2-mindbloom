using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register(
        RegisterRequestDto request)
    {
        var response =
            await _authService.RegisterAsync(request);

        return Ok(response);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login(
        LoginRequestDto request)
    {
        var response =
            await _authService.LoginAsync(request);

        return Ok(response);
    }

    [Authorize]
    [HttpGet("me")]
    public IActionResult Me()
    {
        return Ok(new
        {
            UserId =
                User.FindFirstValue(ClaimTypes.NameIdentifier),

            Email =
                User.FindFirstValue(ClaimTypes.Email),

            Username =
                User.FindFirstValue(ClaimTypes.Name),

            Role =
                User.FindFirstValue(ClaimTypes.Role)
        });
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult>
    ForgotPassword(
        ForgotPasswordDto request)
    {
        await _authService
            .ForgotPasswordAsync(request);

        return Ok(
            "Password reset code sent.");
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult>
    ResetPassword(
        ResetPasswordDto request)
    {
        await _authService
            .ResetPasswordAsync(request);

        return Ok(
            "Password reset successful.");
    }

    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult>
    ChangePassword(
        ChangePasswordDto request)
    {
        var userId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

        await _authService.ChangePasswordAsync(
            userId,
            request);

        return Ok(
            new
            {
                message =
                    "Password changed successfully."
            });
    }
}