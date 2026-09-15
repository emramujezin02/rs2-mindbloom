using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Authentication;

public sealed class RegisterApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public RegisterApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        Register_WithValidRequest_ReturnsOkAndCreatesClientAccount()
    {
        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Client);

        var publisher =
            _factory
                .GetTestNotificationPublisher();

        publisher.Reset();

        var unique =
            Guid.NewGuid()
                .ToString("N");

        var email =
            $"register-{unique}@mindbloom.test";

        var username =
            $"register_{unique}";

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/register",
                CreateValidRequest(
                    email,
                    username));

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var result =
            await response.Content
                .ReadFromJsonAsync<
                    AuthResponseDto>();

        Assert.NotNull(
            result);

        Assert.True(
            result!.Id > 0);

        Assert.Equal(
            "Integration",
            result.FirstName);

        Assert.Equal(
            "Client",
            result.LastName);

        Assert.Equal(
            email,
            result.Email);

        Assert.Equal(
            RoleConstants.Client,
            result.Role);

        Assert.False(
            string.IsNullOrWhiteSpace(
                result.Token));

        Assert.False(
            string.IsNullOrWhiteSpace(
                result.RefreshToken));

        using var scope =
            _factory.Services
                .CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var user =
            await context.Users
                .AsNoTracking()
                .SingleAsync(x =>
                    x.Id ==
                    result.Id);

        Assert.Equal(
            email,
            user.Email);

        var clientProfile =
            await context.Clients
                .AsNoTracking()
                .SingleOrDefaultAsync(x =>
                    x.UserId ==
                    result.Id);

        Assert.NotNull(
            clientProfile);

        var consents =
            await context.UserConsents
                .AsNoTracking()
                .Where(x =>
                    x.UserId ==
                    result.Id)
                .ToListAsync();

        Assert.Equal(
            2,
            consents.Count);

        Assert.Contains(
            consents,
            x =>
                x.ConsentType ==
                    UserConsentType
                        .PrivacyPolicy &&
                x.IsAccepted);

        Assert.Contains(
            consents,
            x =>
                x.ConsentType ==
                    UserConsentType
                        .TermsOfService &&
                x.IsAccepted);

        var verificationCodes =
            await context
                .EmailVerificationCodes
                .AsNoTracking()
                .Where(x =>
                    x.UserId ==
                    result.Id)
                .ToListAsync();

        Assert.Single(
            verificationCodes);

        Assert.False(
            verificationCodes[0]
                .IsUsed);

        Assert.True(
            verificationCodes[0]
                .ExpiresAtUtc >
            DateTime.UtcNow);

        var refreshTokens =
            await context.RefreshTokens
                .AsNoTracking()
                .Where(x =>
                    x.UserId ==
                    result.Id)
                .ToListAsync();

        Assert.Single(
            refreshTokens);

        Assert.False(
            refreshTokens[0]
                .IsRevoked);

        var emailMessage =
            Assert.Single(
                publisher.Messages);

        Assert.Equal(
            email,
            emailMessage
                .RecipientEmail);

        Assert.Equal(
            NotificationEventType
                .EmailVerificationRequested,
            emailMessage.EventType);

        Assert.Contains(
            "verification",
            emailMessage.Subject,
            StringComparison
                .OrdinalIgnoreCase);
    }

    [Fact]
    public async Task
        Register_WhenPrivacyPolicyIsNotAccepted_ReturnsBadRequest()
    {
        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Client);

        var unique =
            Guid.NewGuid()
                .ToString("N");

        var request =
            CreateValidRequest(
                $"privacy-{unique}@mindbloom.test",
                $"privacy_{unique}");

        request.AcceptPrivacyPolicy =
            false;

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/register",
                request);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "Privacy policy must be accepted",
            body,
            StringComparison
                .OrdinalIgnoreCase);
    }

    [Fact]
    public async Task
        Register_WhenEmailAlreadyExists_ReturnsConflict()
    {
        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Client);

        var unique =
            Guid.NewGuid()
                .ToString("N");

        var email =
            $"duplicate-{unique}@mindbloom.test";

        using var client =
            _factory.CreateClient();

        var firstResponse =
            await client.PostAsJsonAsync(
                "/api/Auth/register",
                CreateValidRequest(
                    email,
                    $"first_{unique}"));

        Assert.Equal(
            HttpStatusCode.OK,
            firstResponse.StatusCode);

        var secondRequest =
            CreateValidRequest(
                email,
                $"second_{unique}");

        var secondResponse =
            await client.PostAsJsonAsync(
                "/api/Auth/register",
                secondRequest);

        Assert.Equal(
            HttpStatusCode.Conflict,
            secondResponse.StatusCode);

        var body =
            await secondResponse.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "email already exists",
            body,
            StringComparison
                .OrdinalIgnoreCase);
    }

    [Fact]
    public async Task
        Register_WhenGenderIsInvalid_ReturnsBadRequest()
    {
        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Client);

        var unique =
            Guid.NewGuid()
                .ToString("N");

        var request =
            CreateValidRequest(
                $"gender-{unique}@mindbloom.test",
                $"gender_{unique}");

        request.Gender =
            "InvalidGender";

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/register",
                request);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "Male, Female or Other",
            body,
            StringComparison
                .OrdinalIgnoreCase);
    }

    private static RegisterRequestDto
        CreateValidRequest(
            string email,
            string username)
    {
        return new RegisterRequestDto
        {
            FirstName =
                "Integration",

            LastName =
                "Client",

            Email =
                email,

            Username =
                username,

            Password =
                "IntegrationPassword123!",

            DateOfBirth =
                new DateTime(
                    2000,
                    1,
                    1),

            Gender =
                "Female",

            AcceptPrivacyPolicy =
                true,

            PrivacyPolicyVersion =
                ConsentDocumentConstants
                    .PrivacyPolicyVersion,

            AcceptTermsOfService =
                true,

            TermsOfServiceVersion =
                ConsentDocumentConstants
                    .TermsOfServiceVersion
        };
    }
}