using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Domain.Entities;

namespace MindBloom.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly UserManager<ApplicationUser>
        _userManager;

    public AdminService(
        UserManager<ApplicationUser>
            userManager)
    {
        _userManager = userManager;
    }

    public async Task<List<UserListDto>>
        GetUsersAsync()
    {
        var users =
            await _userManager.Users
                .OrderByDescending(x =>
                    x.CreatedAtUtc)
                .ToListAsync();

        var result =
            new List<UserListDto>();

        foreach (var user in users)
        {
            var roles =
                await _userManager
                    .GetRolesAsync(user);

            result.Add(new UserListDto
            {
                Id = user.Id,

                FirstName =
                    user.FirstName,

                LastName =
                    user.LastName,

                Email =
                    user.Email!,

                Role =
                    roles.FirstOrDefault()
                    ?? "No Role",

                IsEmailVerified =
                    user.IsEmailVerified,

                CreatedAtUtc =
                    user.CreatedAtUtc
            });
        }

        return result;
    }
}