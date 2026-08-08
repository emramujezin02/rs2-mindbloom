using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;
using Xunit;

namespace MindBloom.SecurityTests.Authentication;

public sealed class PasswordResetSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public PasswordResetSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        ResetPassword_WhenTokenIsReused_IsRejected()
    {
        const int userId =
            94001;

        const string email =
            "password-reset-reuse@security.test";

        const string firstPassword =
            "InitialPassword123!";

        const string newPassword =
            "ChangedPassword123!";

        const string secondPassword =
            "ShouldNotBeAccepted123!";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                email,
                firstPassword);

        var resetToken =
            await _factory
                .CreatePasswordResetTokenAsync(
                    userId);

        using var client =
            _factory.CreateClient();

        /*
         * Prvo korištenje tokena
         * mora uspjeti.
         */
        var firstResponse =
            await client.PostAsJsonAsync(
                "/api/Auth/reset-password",
                new
                {
                    email,
                    token =
                        resetToken,
                    newPassword
                });

        Assert.True(
            firstResponse.IsSuccessStatusCode,
            $"Expected successful password reset, but received {(int)firstResponse.StatusCode}.");

        /*
         * Isti token pokušavamo
         * iskoristiti drugi put.
         */
        var reuseResponse =
            await client.PostAsJsonAsync(
                "/api/Auth/reset-password",
                new
                {
                    email,
                    token =
                        resetToken,
                    newPassword =
                        secondPassword
                });

        Assert.Equal(
            HttpStatusCode.BadRequest,
            reuseResponse.StatusCode);

        /*
         * Provjeravamo i stanje baze.
         * Reset request mora ostati
         * označen kao iskorišten.
         */
        using var scope =
            _factory.Services
                .CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var resetRequest =
            await context.PasswordResetCodes
                .Where(x =>
                    x.Email ==
                        email)
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .FirstAsync();

        Assert.True(
            resetRequest.IsUsed);

        Assert.NotNull(
            resetRequest.UsedAtUtc);
    }
}