using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.SecurityTests.Authentication;

public sealed class LoginSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public LoginSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        Login_RepeatedInvalidPassword_IncreasesFailedAccessCount()
    {
        const int userId =
            95001;

        const string email =
            "bruteforce-test@mindbloom.test";

        const string correctPassword =
            "CorrectPassword123!";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                email,
                correctPassword);

        using var scope =
            _factory.Services
                .CreateScope();

        var authService =
            scope.ServiceProvider
                .GetRequiredService<
                    IAuthService>();

        var userManager =
            scope.ServiceProvider
                .GetRequiredService<
                    UserManager<ApplicationUser>>();

        await Assert.ThrowsAsync<
            UnauthorizedException>(
            () =>
                authService.LoginAsync(
                    new LoginRequestDto
                    {
                        Email =
                            email,

                        Password =
                            "WrongPassword123!"
                    }));

        var user =
            await userManager
                .FindByIdAsync(
                    userId.ToString());

        Assert.NotNull(user);

        Assert.Equal(
            1,
            user!.AccessFailedCount);
    }

    [Fact]
    public async Task
        Login_MaximumFailedAttempts_LocksAccountTemporarily()
    {
        const int userId =
            95002;

        const string email =
            "lockout-test@mindbloom.test";

        const string correctPassword =
            "CorrectPassword123!";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                email,
                correctPassword);

        using var scope =
            _factory.Services
                .CreateScope();

        var authService =
            scope.ServiceProvider
                .GetRequiredService<
                    IAuthService>();

        var userManager =
            scope.ServiceProvider
                .GetRequiredService<
                    UserManager<ApplicationUser>>();

        for (var attempt = 0;
             attempt < 5;
             attempt++)
        {
            await Assert.ThrowsAsync<
                UnauthorizedException>(
                () =>
                    authService.LoginAsync(
                        new LoginRequestDto
                        {
                            Email =
                                email,

                            Password =
                                "WrongPassword123!"
                        }));
        }

        var user =
            await userManager
                .FindByIdAsync(
                    userId.ToString());

        Assert.NotNull(user);

        Assert.True(
            user!.LockoutEnd.HasValue);

        Assert.True(
            user.LockoutEnd.Value >
            DateTimeOffset.UtcNow);

        var isLockedOut =
            await userManager
                .IsLockedOutAsync(user);

        Assert.True(
            isLockedOut);
    }

    [Fact]
    public async Task
        Login_LockedAccount_DoesNotAuthenticateWithCorrectPassword()
    {
        const int userId =
            95003;

        const string email =
            "locked-correct-password@mindbloom.test";

        const string correctPassword =
            "CorrectPassword123!";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                email,
                correctPassword);

        using var scope =
            _factory.Services
                .CreateScope();

        var authService =
            scope.ServiceProvider
                .GetRequiredService<
                    IAuthService>();

        var userManager =
            scope.ServiceProvider
                .GetRequiredService<
                    UserManager<ApplicationUser>>();

        for (var attempt = 0;
             attempt < 5;
             attempt++)
        {
            await Assert.ThrowsAsync<
                UnauthorizedException>(
                () =>
                    authService.LoginAsync(
                        new LoginRequestDto
                        {
                            Email =
                                email,

                            Password =
                                "WrongPassword123!"
                        }));
        }

        var user =
            await userManager
                .FindByIdAsync(
                    userId.ToString());

        Assert.NotNull(user);

        var isLockedOut =
            await userManager
                .IsLockedOutAsync(
                    user!);

        Assert.True(
            isLockedOut);

        await Assert.ThrowsAsync<
            UnauthorizedException>(
            () =>
                authService.LoginAsync(
                    new LoginRequestDto
                    {
                        Email =
                            email,

                        Password =
                            correctPassword
                    }));
    }
}