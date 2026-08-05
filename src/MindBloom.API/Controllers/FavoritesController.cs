using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Favorites.DTOs;
using MindBloom.Application.Features.Favorites.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;
[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = "ClientOnly")]
public class FavoritesController : ControllerBase
{
    private readonly IFavoriteService
        _favoriteService;

    public FavoritesController(
        IFavoriteService favoriteService)
    {
        _favoriteService = favoriteService;
    }

    [HttpPost]
    public async Task<IActionResult> Add(
        AddFavoriteDto request)
    {
        var userId =
            GetCurrentUserId();

        await _favoriteService.AddAsync(
            userId,
            request);

        return Ok(new
        {
            message =
                "Therapist added to favorites."
        });
    }

    [HttpDelete("{therapistId}")]
    public async Task<IActionResult> Remove(
        int therapistId)
    {
        var userId =
            GetCurrentUserId();

        await _favoriteService.RemoveAsync(
            userId,
            therapistId);

        return Ok(new
        {
            message =
                "Therapist removed from favorites."
        });
    }

    [HttpGet("mine")]
    public async Task<IActionResult>
        GetMyFavorites()
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _favoriteService
                .GetMyFavoritesAsync(userId);

        return Ok(result);
    }

    private int GetCurrentUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId) ||
            userId <= 0)
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is missing or invalid.");
        }

        return userId;
    }
}