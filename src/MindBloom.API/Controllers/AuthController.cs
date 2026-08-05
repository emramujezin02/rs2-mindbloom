using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = "AuthenticatedUser")]
public sealed class AuthController
    : ControllerBase
{
    private readonly IAuthService
        _authService;

    public AuthController(
        IAuthService authService)
    {
        _authService =
            authService;
    }

    /*
     * JAVNI AUTH ENDPOINTI
     */

    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<IActionResult> Register(
        [FromBody]
        RegisterRequestDto request)
    {
        var response =
            await _authService
                .RegisterAsync(request);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login(
        [FromBody]
        LoginRequestDto request)
    {
        var response =
            await _authService
                .LoginAsync(request);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("forgot-password")]
    public async Task<IActionResult>
        ForgotPassword(
            [FromBody]
            ForgotPasswordDto request)
    {
        await _authService
            .ForgotPasswordAsync(request);

        return Ok(
            new
            {
                message =
                    "If an account with the provided email exists, password reset instructions have been sent."
            });
    }

    [AllowAnonymous]
    [HttpPost("reset-password")]
    public async Task<IActionResult>
        ResetPassword(
            [FromBody]
            ResetPasswordDto request)
    {
        await _authService
            .ResetPasswordAsync(request);

        return Ok(
            new
            {
                message =
                    "Password reset successful."
            });
    }

    [AllowAnonymous]
    [HttpPost("send-verification-email")]
    public async Task<IActionResult>
        SendVerificationEmail(
            [FromBody]
            ForgotPasswordDto request)
    {
        await _authService
            .SendVerificationEmailAsync(
                request.Email);

        return Ok(
            new
            {
                message =
                    "If the account is eligible for verification, a verification email has been sent."
            });
    }

    [AllowAnonymous]
    [HttpGet("verify-email")]
    public async Task<IActionResult>
        VerifyEmail(
            [FromQuery]
            VerifyEmailDto request)
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

    [AllowAnonymous]
    [HttpPost("refresh-token")]
    public async Task<IActionResult>
        RefreshToken(
            [FromBody]
            RefreshTokenRequestDto request)
    {
        var response =
            await _authService
                .RefreshTokenAsync(request);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("login-2fa")]
    public async Task<IActionResult>
        LoginWith2FA(
            [FromBody]
            LoginRequestDto request)
    {
        var response =
            await _authService
                .LoginWith2FAAsync(request);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("verify-2fa")]
    public async Task<IActionResult>
        Verify2FA(
            [FromBody]
            Verify2FADto request)
    {
        var response =
            await _authService
                .Verify2FAAsync(request);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("send-verification-code")]
    public async Task<IActionResult>
        SendVerificationCode(
            [FromBody]
            SendEmailVerificationCodeDto request)
    {
        await _authService
            .SendEmailVerificationCodeAsync(
                request.Email);

        return Ok(
            new
            {
                message =
                    "If the account is eligible for verification, a verification code has been sent."
            });
    }

    [AllowAnonymous]
    [HttpPost("verify-email-code")]
    public async Task<IActionResult>
        VerifyEmailCode(
            [FromBody]
            VerifyEmailCodeDto request)
    {
        await _authService
            .VerifyEmailCodeAsync(request);

        return Ok(
            new
            {
                message =
                    "Email verified successfully."
            });
    }

    /*
     * AUTENTIFIKOVANI AUTH ENDPOINTI
     */

    [HttpGet("me")]
    public IActionResult Me()
    {
        return Ok(
            new
            {
                UserId =
                    User.FindFirstValue(
                        ClaimTypes.NameIdentifier),

                Email =
                    User.FindFirstValue(
                        ClaimTypes.Email),

                Username =
                    User.FindFirstValue(
                        ClaimTypes.Name),

                Role =
                    User.FindFirstValue(
                        ClaimTypes.Role)
            });
    }

    [HttpPost("change-password")]
    public async Task<IActionResult>
        ChangePassword(
            [FromBody]
            ChangePasswordDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        await _authService
            .ChangePasswordAsync(
                userId,
                request);

        return Ok(
            new
            {
                message =
                    "Password changed successfully."
            });
    }

    [HttpDelete("delete-account")]
    public async Task<IActionResult>
        DeleteAccount(
            [FromBody]
            DeleteAccountRequestDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        await _authService
            .DeleteAccountAsync(
                userId,
                request);

        return Ok(
            new
            {
                message =
                    "Account deleted successfully."
            });
    }

    [HttpPost("enable-2fa")]
    public async Task<IActionResult>
        Enable2FA()
    {
        var userId =
            GetAuthenticatedUserId();

        await _authService
            .Enable2FAAsync(userId);

        return Ok(
            new
            {
                message =
                    "2FA enabled successfully."
            });
    }

    [HttpPost("disable-2fa")]
    public async Task<IActionResult>
        Disable2FA()
    {
        var userId =
            GetAuthenticatedUserId();

        await _authService
            .Disable2FAAsync(userId);

        return Ok(
            new
            {
                message =
                    "2FA disabled successfully."
            });
    }

    [HttpPost("logout")]
    public async Task<IActionResult>
        Logout()
    {
        var userId =
            GetAuthenticatedUserId();

        await _authService
            .LogoutAsync(userId);

        return Ok(
            new
            {
                message =
                    "Logged out successfully."
            });
    }

    [HttpGet("2fa-status")]
    public async Task<IActionResult>
        Get2FAStatus()
    {
        var userId =
            GetAuthenticatedUserId();

        var isEnabled =
            await _authService
                .Is2FAEnabledAsync(userId);

        return Ok(
            new
            {
                isEnabled
            });
    }

    private int GetAuthenticatedUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId) ||
            userId <= 0)
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is missing or invalid.");
        }

        return userId;
    }
}