using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Articles.DTOs;
using MindBloom.Application.Features.Articles.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public class ArticlesController : ControllerBase
{
    private readonly IArticleService
        _articleService;

    public ArticlesController(
        IArticleService articleService)
    {
        _articleService =
            articleService;
    }

    [AllowAnonymous]
    [HttpGet]
    public async Task<IActionResult>
        GetPublic(
            [FromQuery]
            ArticleQueryDto query)
    {
        var result =
            await _articleService
                .GetPublicAsync(
                    query);

        return Ok(result);
    }

    [AllowAnonymous]
    [HttpGet("{id:int}")]
    public async Task<IActionResult>
        GetById(
            int id)
    {
        var result =
            await _articleService
                .GetByIdAsync(
                    id);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOnly)]
    [HttpGet("management")]
    public async Task<IActionResult>
        GetManagement(
            [FromQuery]
            ArticleManagementQueryDto query)
    {
        var result =
            await _articleService
                .GetManagementAsync(
                    query);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOnly)]
    [HttpGet("management/{id:int}")]
    public async Task<IActionResult>
        GetManagementById(
            int id)
    {
        var result =
            await _articleService
                .GetManagementByIdAsync(
                    id);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpPost]
    public async Task<IActionResult>
        Create(
            CreateArticleDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _articleService
                .CreateAsync(
                    userId,
                    isAdmin,
                    request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpPut("{id:int}")]
    public async Task<IActionResult>
        Update(
            int id,
            UpdateArticleDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _articleService
                .UpdateAsync(
                    userId,
                    isAdmin,
                    id,
                    request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpPut("{id:int}/publication")]
    public async Task<IActionResult>
        UpdatePublication(
            int id,
            UpdateArticlePublicationDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _articleService
                .UpdatePublicationAsync(
                    userId,
                    isAdmin,
                    id,
                    request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult>
        Delete(
            int id)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        await _articleService
            .DeleteAsync(
                userId,
                isAdmin,
                id);

        return Ok(new
        {
            message =
                "Article deleted successfully."
        });
    }

    private int GetAuthenticatedUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId))
        {
            throw new UnauthorizedException(
                "Invalid authenticated user.");
        }

        return userId;
    }

    [AllowAnonymous]
    [HttpGet("categories")]
    public async Task<IActionResult>
    GetCategories()
    {
        var result =
            await _articleService
                .GetCategoriesAsync();

        return Ok(result);
    }

    [HttpPost("image")]
    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<
        ActionResult<ArticleImageUploadDto>>
        UploadImage(
            IFormFile file)
    {
        var result =
            await _articleService
                .UploadImageAsync(file);

        return Ok(result);
    }
}