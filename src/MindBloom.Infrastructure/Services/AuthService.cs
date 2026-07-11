using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;
using MindBloom.Application.Features.Auth.DTOs;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Auth.DTOs;


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

    private bool IsDemoAccount(string email)
    {
        var demoEmails = new List<string>
    {
        "therapist@mindbloom.ba",
        "client@mindbloom.ba",
        "admin@mindbloom.ba"
    };

        return demoEmails.Contains(
            email.ToLower());
    }

    public async Task<AuthResponseDto> RegisterAsync(
     RegisterRequestDto request)
    {
        const string clientRole = "Client";

        var normalizedEmail =
            request.Email.Trim().ToLowerInvariant();

        var normalizedUsername =
            request.Username.Trim();

        var existingEmailUser =
            await _userManager.FindByEmailAsync(
                normalizedEmail);

        if (existingEmailUser != null)
        {
            throw new Exception(
                "A user with this email already exists.");
        }

        var existingUsernameUser =
            await _userManager.FindByNameAsync(
                normalizedUsername);

        if (existingUsernameUser != null)
        {
            throw new Exception(
                "A user with this username already exists.");
        }

        var user = new ApplicationUser
        {
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            Email = normalizedEmail,
            UserName = normalizedUsername,
            DateOfBirth = request.DateOfBirth,
            CreatedAtUtc = DateTime.UtcNow,
            EmailConfirmed =
                IsDemoAccount(normalizedEmail),
            IsEmailVerified =
                IsDemoAccount(normalizedEmail)
        };

        var createResult =
            await _userManager.CreateAsync(
                user,
                request.Password);

        if (!createResult.Succeeded)
        {
            throw new Exception(
                string.Join(
                    ", ",
                    createResult.Errors.Select(
                        error => error.Description)));
        }

        var addRoleResult =
            await _userManager.AddToRoleAsync(
                user,
                clientRole);

        if (!addRoleResult.Succeeded)
        {
            await _userManager.DeleteAsync(user);

            throw new Exception(
                string.Join(
                    ", ",
                    addRoleResult.Errors.Select(
                        error => error.Description)));
        }

        var client = new Client
        {
            UserId = user.Id
        };

        _context.Clients.Add(client);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            await _userManager.DeleteAsync(user);
            throw;
        }

        if (!IsDemoAccount(user.Email!))
        {
            await SendVerificationEmailAsync(
                user.Email!);
        }

        var token =
            await _jwtTokenService.GenerateTokenAsync(
                user);

        var refreshToken =
            _jwtTokenService.GenerateRefreshToken();

        var refreshTokenEntity =
            new RefreshToken
            {
                UserId = user.Id,
                Token = refreshToken,
                ExpiresAtUtc =
                    DateTime.UtcNow.AddDays(7),
                IsRevoked = false
            };

        _context.RefreshTokens.Add(
            refreshTokenEntity);

        await _context.SaveChangesAsync();

        return new AuthResponseDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email!,
            Token = token,
            Role = clientRole,
            RefreshToken = refreshToken
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

        if (user.IsBlocked)
        {
            throw new Exception(
                "Your account is blocked.");
        }

        if (!user.IsEmailVerified
    && !IsDemoAccount(user.Email!))
        {
            throw new Exception(
                "Email is not verified.");
        }

        var isPasswordValid =
            await _userManager.CheckPasswordAsync(
                user,
                request.Password);

        if (!isPasswordValid)
        {
            throw new Exception("Invalid credentials.");
        }
        var oldTokens =
    await _context.RefreshTokens
        .Where(x =>
            x.UserId == user.Id
            && !x.IsRevoked)
        .ToListAsync();

        foreach (var oldToken in oldTokens)
        {
            oldToken.IsRevoked = true;
        }


        var roles = await _userManager.GetRolesAsync(user);

        var token = await _jwtTokenService.GenerateTokenAsync(user);

        var refreshToken =_jwtTokenService.GenerateRefreshToken();

        var refreshTokenEntity =
    new RefreshToken
    {
        UserId = user.Id,

        Token = refreshToken,

        ExpiresAtUtc =
    request.RememberMe
        ? DateTime.UtcNow.AddDays(30)
        : DateTime.UtcNow.AddDays(1),

        IsRevoked = false
    };

        _context.RefreshTokens.Add(
            refreshTokenEntity);

        await _context.SaveChangesAsync();

        return new AuthResponseDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email!,
            Token = token,
            Role = roles.First(),
            RefreshToken=refreshToken,
            
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

        if (!IsDemoAccount(user.Email!))
        {
            await _emailService.SendAsync(
                user.Email!,
                "Reset Password Code",
                $"Your reset code is: {code}");
        }
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

    public async Task ChangePasswordAsync(
    int userId,
    ChangePasswordDto request)
    {
        var user =
            await _userManager
                .FindByIdAsync(userId.ToString());

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var result =
            await _userManager.ChangePasswordAsync(
                user,
                request.CurrentPassword,
                request.NewPassword);

        if (!result.Succeeded)
        {
            throw new Exception(
                result.Errors.First().Description);
        }
    }

    public async Task SendVerificationEmailAsync(
    string email)
    {
        var user =
            await _userManager
                .FindByEmailAsync(email);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var token =
            await _userManager
                .GenerateEmailConfirmationTokenAsync(
                    user);

        var encodedToken =
            Uri.EscapeDataString(token);

        var verificationLink =
            $"http://localhost:5110/api/auth/verify-email?email={user.Email}&token={encodedToken}";

        var body =
    $@"Click the link below to verify your email:

{verificationLink}";

        await _emailService.SendAsync(
            user.Email!,
            "MindBloom Email Verification",
            body);
    }

    public async Task VerifyEmailAsync(
    VerifyEmailDto request)
    {
        var user =
            await _userManager
                .FindByEmailAsync(request.Email);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var result =
            await _userManager
                .ConfirmEmailAsync(
                    user,
                    request.Token);

        if (!result.Succeeded)
        {
            throw new Exception(
                "Invalid verification token.");
        }

        user.IsEmailVerified = true;

        await _userManager.UpdateAsync(user);
    }

    public async Task<AuthResponseDto>
    RefreshTokenAsync(
        RefreshTokenRequestDto request)
    {
        var refreshToken =
            await _context.RefreshTokens
                .Include(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Token == request.RefreshToken);

        if (refreshToken == null)
        {
            throw new Exception(
                "Invalid refresh token.");
        }

        if (refreshToken.IsRevoked)
        {
            throw new Exception(
                "Refresh token revoked.");
        }

        if (refreshToken.ExpiresAtUtc
            < DateTime.UtcNow)
        {
            throw new Exception(
                "Refresh token expired.");
        }

        refreshToken.IsRevoked = true;

        var newJwtToken =
            await _jwtTokenService
                .GenerateTokenAsync(
                    refreshToken.User);

        var newRefreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

        var newRefreshTokenEntity =
            new RefreshToken
            {
                UserId =
                    refreshToken.UserId,

                Token =
                    newRefreshToken,

                ExpiresAtUtc =
                    DateTime.UtcNow.AddDays(7),

                IsRevoked = false
               
            };

        _context.RefreshTokens.Add(
            newRefreshTokenEntity);

        await _context.SaveChangesAsync();

        var roles = await _userManager.GetRolesAsync(refreshToken.User);

        return new AuthResponseDto
        {
            Token = newJwtToken,
            RefreshToken = newRefreshToken,
            Id=refreshToken.Id,
            FirstName=refreshToken.User.FirstName,
            LastName=refreshToken.User.LastName,
            Email=refreshToken.User.Email,
            Role=roles.First()
        };
    }

    public async Task DeleteAccountAsync(
    int userId,
    DeleteAccountRequestDto request)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        var isPasswordCorrect =
            await _userManager.CheckPasswordAsync(
                user,
                request.Password);

        if (!isPasswordCorrect)
        {
            throw new Exception("Invalid password.");
        }

        var refreshTokens =
            await _context.RefreshTokens
                .Where(x => x.UserId == user.Id)
                .ToListAsync();

        _context.RefreshTokens.RemoveRange(
            refreshTokens);

        var therapist =
            await _context.Therapists
                .FirstOrDefaultAsync(x =>
                    x.UserId == user.Id);

        if (therapist != null)
        {
            _context.Therapists.Remove(therapist);
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == user.Id);

        if (client != null)
        {
            _context.Clients.Remove(client);
        }

        await _context.SaveChangesAsync();

        var result =
            await _userManager.DeleteAsync(user);

        if (!result.Succeeded)
        {
            throw new Exception(
                "Failed to delete account.");
        }
    }

    public async Task<Login2FAResponseDto>
    LoginWith2FAAsync(
        LoginRequestDto request)
    {
        var user =
            await _userManager
                .FindByEmailAsync(request.Email);

        if (user == null)
        {
            throw new Exception(
                "Invalid credentials.");
        }

        var isPasswordValid =
            await _userManager
                .CheckPasswordAsync(
                    user,
                    request.Password);

        if (!isPasswordValid)
        {
            throw new Exception(
                "Invalid credentials.");
        }

        if (!user.TwoFactorEnabledCustom)
        {
            throw new Exception(
                "2FA is not enabled.");
        }

        if (IsDemoAccount(user.Email!))
        {
            var roles =
                await _userManager.GetRolesAsync(user);

            var token =
                await _jwtTokenService
                    .GenerateTokenAsync(user);

            var refreshToken =
                _jwtTokenService
                    .GenerateRefreshToken();

            return new Login2FAResponseDto
            {
                RequiresTwoFactor = false,
                Message = "Demo account login successful."
            };
        }

        var code =
            new Random()
                .Next(100000, 999999)
                .ToString();

        user.TwoFactorCode = code;

        user.TwoFactorCodeExpiresAtUtc =
            DateTime.UtcNow.AddMinutes(5);

        await _userManager.UpdateAsync(user);

        if (!IsDemoAccount(user.Email!))
        {
            await _emailService.SendAsync(
                user.Email!,
                "MindBloom 2FA Code",
                $"Your verification code is: {code}");
        }

        return new Login2FAResponseDto
        {
            RequiresTwoFactor = true,
            Message =
                "2FA code sent to email."
        };
    }

    public async Task<AuthResponseDto>
    Verify2FAAsync(
        Verify2FADto request)
    {
        var user =
            await _userManager
                .FindByEmailAsync(request.Email);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        if (!IsDemoAccount(user.Email!))
        {
            if (user.TwoFactorCode != request.Code)
            {
                throw new Exception(
                    "Invalid code.");
            }
        }

        if (user.TwoFactorCodeExpiresAtUtc
            < DateTime.UtcNow)
        {
            throw new Exception(
                "Code expired.");
        }

        user.TwoFactorCode = null;

        user.TwoFactorCodeExpiresAtUtc = null;

        await _userManager.UpdateAsync(user);

        var roles =
            await _userManager
                .GetRolesAsync(user);

        var token =
            await _jwtTokenService
                .GenerateTokenAsync(user);

        var refreshToken =
            _jwtTokenService
                .GenerateRefreshToken();

        return new AuthResponseDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email!,
            Token = token,
            RefreshToken = refreshToken,
            Role = roles.First()
        };
    }

    public async Task Enable2FAAsync(
    int userId)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        user.TwoFactorEnabledCustom = true;

        await _userManager.UpdateAsync(user);
    }

    public async Task Disable2FAAsync(
    int userId)
    {
        var user =
            await _userManager.Users
                .FirstOrDefaultAsync(x =>
                    x.Id == userId);

        if (user == null)
        {
            throw new Exception("User not found.");
        }

        user.TwoFactorEnabledCustom = false;

        await _userManager.UpdateAsync(user);
    }

    public async Task LogoutAsync(
    int userId)
    {
        var userExists =
            await _userManager.Users
                .AnyAsync(x =>
                    x.Id == userId);

        if (!userExists)
        {
            throw new Exception(
                "User not found.");
        }

        var activeRefreshTokens =
            await _context.RefreshTokens
                .Where(x =>
                    x.UserId == userId
                    && !x.IsRevoked)
                .ToListAsync();

        if (activeRefreshTokens.Count == 0)
        {
            return;
        }

        foreach (var refreshToken
                 in activeRefreshTokens)
        {
            refreshToken.IsRevoked = true;
        }

        await _context.SaveChangesAsync();
    }
}