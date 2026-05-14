using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;


namespace MindBloom.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;

    private readonly IJwtTokenService _jwtTokenService;

    private readonly ApplicationDbContext _context;

    private readonly IEmailService _emailService;
    public AuthService(
        UserManager<ApplicationUser> userManager,
        IJwtTokenService jwtTokenService,
        ApplicationDbContext context,
        IEmailService emailService)
    {
        _userManager = userManager;
        _jwtTokenService = jwtTokenService;
        _context = context;
        _emailService = emailService;
    }

    public async Task<AuthResponseDto> RegisterAsync(
        RegisterRequestDto request)
    {
        var existingUser =
            await _userManager.FindByEmailAsync(request.Email);

        if (existingUser != null)
        {
            throw new Exception("User already exists.");
        }

        var user = new ApplicationUser
        {
            FirstName = request.FirstName,
            LastName = request.LastName,
            Email = request.Email,
            UserName = request.Username,
            DateOfBirth = request.DateOfBirth,
            CreatedAtUtc = DateTime.Now,
            EmailConfirmed = true
        };

        var result =
            await _userManager.CreateAsync(user, request.Password);

        if (!result.Succeeded)
        {
            throw new Exception(
                string.Join(", ", result.Errors.Select(x => x.Description)));
        }

        await _userManager.AddToRoleAsync(
    user,
    RoleConstants.Client);

        var client = new Client
        {
            UserId = user.Id
        };

        _context.Clients.Add(client);

        await _context.SaveChangesAsync();

        await _userManager.AddToRoleAsync(user, request.Role);

        var token =
            await _jwtTokenService.GenerateTokenAsync(user);

        return new AuthResponseDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email!,
            Token = token,
            Role = request.Role
        };
    }

    public async Task<AuthResponseDto> LoginAsync(
        LoginRequestDto request)
    {
        var user =
            await _userManager.FindByEmailAsync(request.Email);

        if (user == null)
        {
            throw new Exception("Invalid credentials.");
        }

        var isPasswordValid =
            await _userManager.CheckPasswordAsync(
                user,
                request.Password);

        if (!isPasswordValid)
        {
            throw new Exception("Invalid credentials.");
        }

        var roles =
            await _userManager.GetRolesAsync(user);

        var token =
            await _jwtTokenService.GenerateTokenAsync(user);

        return new AuthResponseDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email!,
            Token = token,
            Role = roles.First()
        };
    }

    public async Task ForgotPasswordAsync(
    ForgotPasswordDto request)
    {
        var user =
            await _userManager.FindByEmailAsync(
                request.Email);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var code =
            new Random()
                .Next(100000, 999999)
                .ToString();

        var resetCode =
            new PasswordResetCode
            {
                Email = request.Email,

                Code = code,

                ExpiresAtUtc =
                    DateTime.UtcNow.AddMinutes(10),

                IsUsed = false
            };

        _context.PasswordResetCodes.Add(resetCode);

        await _context.SaveChangesAsync();

        await _emailService.SendAsync(
            request.Email,
            "MindBloom Password Reset",
            $"Your password reset code is: {code}");
    }

    public async Task ResetPasswordAsync(
    ResetPasswordDto request)
    {
        var user =
            await _userManager.FindByEmailAsync(
                request.Email);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var resetCode =
            await _context.PasswordResetCodes
                .OrderByDescending(x => x.CreatedAtUtc)
                .FirstOrDefaultAsync(x =>
                    x.Email == request.Email
                    && x.Code == request.Code
                    && !x.IsUsed);

        if (resetCode == null)
        {
            throw new Exception("Invalid code.");
        }

        if (resetCode.ExpiresAtUtc < DateTime.UtcNow)
        {
            throw new Exception("Code expired.");
        }

        var resetToken =
            await _userManager
                .GeneratePasswordResetTokenAsync(user);

        var result =
            await _userManager
                .ResetPasswordAsync(
                    user,
                    resetToken,
                    request.NewPassword);

        if (!result.Succeeded)
        {
            throw new Exception(
                result.Errors.First().Description);
        }

        resetCode.IsUsed = true;

        await _context.SaveChangesAsync();
    }
}