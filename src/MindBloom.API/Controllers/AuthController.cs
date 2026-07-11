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

    [HttpPost("send-verification-email")]
    public async Task<IActionResult>
    SendVerificationEmail(
        ForgotPasswordDto request)
    {
        await _authService
            .SendVerificationEmailAsync(
                request.Email);

        return Ok(
            new
            {
                message =
                    "Verification email sent."
            });
    }

    [HttpGet("verify-email")]
    public async Task<IActionResult>
    VerifyEmail(
        [FromQuery] VerifyEmailDto request)
    {
        await _authService
            .VerifyEmailAsync(request);

        return Ok(
            new
            {
                message =
                    "Email verified successfully."
            });
    }

    [HttpPost("refresh-token")]
    public async Task<IActionResult>
    RefreshToken(
        RefreshTokenRequestDto request)
    {
        var response =
            await _authService
                .RefreshTokenAsync(request);

        return Ok(response);
    }

    [Authorize]
    [HttpDelete("delete-account")]
    public async Task<IActionResult> DeleteAccount(
    DeleteAccountRequestDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!.Value);

        await _authService.DeleteAccountAsync(
            userId,
            request);

        return Ok(new
        {
            message =
                "Account deleted successfully."
        });
    }

    [HttpPost("login-2fa")]
    public async Task<IActionResult>
    LoginWith2FA(
        LoginRequestDto request)
    {
        var result =
            await _authService
                .LoginWith2FAAsync(request);

        return Ok(result);
    }

    [HttpPost("verify-2fa")]
    public async Task<IActionResult>
    Verify2FA(
        Verify2FADto request)
    {
        var result =
            await _authService
                .Verify2FAAsync(request);

        return Ok(result);
    }

    [Authorize]
    [HttpPost("enable-2fa")]
    public async Task<IActionResult>
    Enable2FA()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _authService
            .Enable2FAAsync(userId);

        return Ok(new
        {
            message =
                "2FA enabled successfully."
        });
    }

    [Authorize]
    [HttpPost("disable-2fa")]
    public async Task<IActionResult>
    Disable2FA()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _authService
            .Disable2FAAsync(userId);

        return Ok(new
        {
            message =
                "2FA disabled successfully."
        });
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            return Unauthorized(
                new
                {
                    message =
                        "Invalid authenticated user."
                });
        }

        await _authService.LogoutAsync(
            userId);

        return Ok(
            new
            {
                message =
                    "Logged out successfully."
            });
    }

    [Authorize]
    [HttpGet("2fa-status")]
    public async Task<IActionResult>
    Get2FAStatus()
    {
        var userId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

        var isEnabled =
            await _authService
                .Is2FAEnabledAsync(userId);

        return Ok(new
        {
            isEnabled
        });
    }
}