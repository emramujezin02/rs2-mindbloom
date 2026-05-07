using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Persistence.Seed;

public static class ApplicationDbSeeder
{
    public static async Task SeedAsync(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole<int>> roleManager)
    {
        await context.Database.MigrateAsync();

        if (!await roleManager.RoleExistsAsync(RoleConstants.Admin))
        {
            await roleManager.CreateAsync(
                new IdentityRole<int>(RoleConstants.Admin));
        }

        if (!await roleManager.RoleExistsAsync(RoleConstants.Therapist))
        {
            await roleManager.CreateAsync(
                new IdentityRole<int>(RoleConstants.Therapist));
        }

        if (!await roleManager.RoleExistsAsync(RoleConstants.Client))
        {
            await roleManager.CreateAsync(
                new IdentityRole<int>(RoleConstants.Client));
        }


        var adminUser = new ApplicationUser
        {
            UserName = "desktop",
            Email = "desktop@mindbloom.com",
            FirstName = "System",
            LastName = "Administrator",
            EmailConfirmed = true
        };

        var existingAdmin =
            await userManager.FindByNameAsync(adminUser.UserName);

        if (existingAdmin == null)
        {
            var result = await userManager.CreateAsync(
                adminUser,
                "test");

            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(
                    adminUser,
                    RoleConstants.Admin);
            }
        }

        var mobileUser = new ApplicationUser
        {
            UserName = "mobile",
            Email = "mobile@mindbloom.com",
            FirstName = "Mobile",
            LastName = "User",
            EmailConfirmed = true
        };

        var existingMobile =
            await userManager.FindByNameAsync("mobile");

        if (existingMobile == null)
        {
            var createResult =
                await userManager.CreateAsync(
                    mobileUser,
                    "test");

            if (createResult.Succeeded)
            {
                await userManager.AddToRoleAsync(
                    mobileUser,
                    RoleConstants.Client);
            }
        }
    } 
}