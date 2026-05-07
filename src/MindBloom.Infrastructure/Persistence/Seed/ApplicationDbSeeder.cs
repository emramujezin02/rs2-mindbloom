using Microsoft.AspNetCore.Identity;
using MindBloom.Domain.Entities;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Persistence.Seed;

public static class ApplicationDbSeeder
{
    public static async Task SeedAsync(
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole<int>> roleManager)
    {
        var roles = new[]
        {
            RoleConstants.Admin,
            RoleConstants.Client,
            RoleConstants.Therapist
        };

        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(
                    new IdentityRole<int>(role));
            }
        }

        var adminEmail = "desktop@mindbloom.com";

        var existingAdmin =
            await userManager.FindByEmailAsync(adminEmail);

        if (existingAdmin == null)
        {
            var admin = new ApplicationUser
            {
                FirstName = "System",
                LastName = "Administrator",
                Email = adminEmail,
                UserName = adminEmail,
                EmailConfirmed = true
            };

            var result = await userManager.CreateAsync(
                admin,
                "Test123!");

            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(
                    admin,
                    RoleConstants.Admin);
            }
        }
    }
}