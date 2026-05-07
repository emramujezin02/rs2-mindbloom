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
        RegisterRequest request)
    {
        var response =
            await _authService.RegisterAsync(request);

        return Ok(response);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login(
        LoginRequest request)
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
}