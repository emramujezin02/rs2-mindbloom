using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MembershipsController : ControllerBase
{
    private readonly IMembershipService
        _membershipService;

    public MembershipsController(
        IMembershipService membershipService)
    {
        _membershipService =
            membershipService;
    }

    [HttpGet("therapist/{therapistId}/plans")]
    [AllowAnonymous]
    public async Task<IActionResult>
        GetPlansForTherapist(
            int therapistId)
    {
        var result =
            await _membershipService
                .GetPlansForTherapistAsync(
                    therapistId);

        return Ok(result);
    }

    [HttpPost("purchase")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        Purchase(
            PurchaseMembershipDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _membershipService
                .PurchaseAsync(
                    userId,
                    request);

        return Ok(result);
    }

    [HttpGet("mine")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        GetMyMemberships()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _membershipService
                .GetMyMembershipsAsync(
                    userId);

        return Ok(result);
    }

    [HttpPost("use")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        UseMembership(
            UseMembershipDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _membershipService
            .UseMembershipAsync(
                userId,
                request);

        return Ok(new
        {
            message =
                "Membership used successfully."
        });
    }
}