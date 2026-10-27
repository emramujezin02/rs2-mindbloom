using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Domain.Entities;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Authentication;

public sealed class ChangePasswordContractApiTests
{
    [Theory]
    [InlineData("matching", HttpStatusCode.OK)]
    [InlineData("missing", HttpStatusCode.BadRequest)]
    [InlineData("different", HttpStatusCode.BadRequest)]
    public async Task DesktopContract_RequiresConfirmationAndOnlyChangesPasswordWhenValid(
        string confirmation, HttpStatusCode status)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        await factory.SeedActiveUserAsync(501, RoleConstants.Admin, "password-test@test.local", "Previous123!");
        using var client = factory.CreateAuthenticatedClient(501, RoleConstants.Admin);
        var body = new Dictionary<string, string>
        {
            ["currentPassword"] = "Previous123!", ["newPassword"] = "Updated123!"
        };
        if (confirmation != "missing")
            body["confirmNewPassword"] = confirmation == "matching" ? "Updated123!" : "Different123!";
        var response = await client.PostAsJsonAsync("/api/Auth/change-password", body);
        Assert.Equal(status, response.StatusCode);
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await manager.FindByIdAsync("501");
        Assert.NotNull(user);
        Assert.True(await manager.CheckPasswordAsync(user, status == HttpStatusCode.OK ? "Updated123!" : "Previous123!"));
    }
}
