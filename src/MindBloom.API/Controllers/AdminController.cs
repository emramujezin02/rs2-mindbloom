using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Admin.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private readonly IAdminService
        _adminService;

    public AdminController(
        IAdminService adminService)
    {
        _adminService = adminService;
    }

    [HttpGet("users")]
    public async Task<IActionResult>
        GetUsers()
    {
        var result =
            await _adminService
                .GetUsersAsync();

        return Ok(result);
    }
}