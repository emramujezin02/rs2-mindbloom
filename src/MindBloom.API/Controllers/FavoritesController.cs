using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Favorites.DTOs;
using MindBloom.Application.Features.Favorites.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FavoritesController : ControllerBase
{
    private readonly IFavoriteService
        _favoriteService;

    public FavoritesController(
        IFavoriteService favoriteService)
    {
        _favoriteService = favoriteService;
    }

    [Authorize(Roles = "Client")]
    [HttpPost]
    public async Task<IActionResult> Add(
        AddFavoriteDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _favoriteService.AddAsync(
            userId,
            request);

        return Ok(new
        {
            message =
                "Therapist added to favorites."
        });
    }

    [Authorize(Roles = "Client")]
    [HttpDelete("{therapistId}")]
    public async Task<IActionResult> Remove(
        int therapistId)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _favoriteService.RemoveAsync(
            userId,
            therapistId);

        return Ok(new
        {
            message =
                "Therapist removed from favorites."
        });
    }

    [Authorize(Roles = "Client")]
    [HttpGet("mine")]
    public async Task<IActionResult>
        GetMyFavorites()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _favoriteService
                .GetMyFavoritesAsync(userId);

        return Ok(result);
    }
}