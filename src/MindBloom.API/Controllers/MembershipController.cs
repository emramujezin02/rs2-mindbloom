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

    [HttpPost("create-payment-intent")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        CreatePaymentIntent(
            CreateMembershipPaymentIntentDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _membershipService
                .CreatePaymentIntentAsync(
                    userId,
                    request);

        return Ok(result);
    }

    [HttpPost("confirm-payment")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        ConfirmPayment(
            ConfirmMembershipPaymentDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _membershipService
                .ConfirmPaymentAsync(
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
            GetAuthenticatedUserId();

        var result =
            await _membershipService
                .GetMyMembershipsAsync(
                    userId);

        return Ok(result);
    }

    [HttpGet("{membershipId}/receipt")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        GetReceipt(
            int membershipId)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _membershipService
                .GetReceiptAsync(
                    userId,
                    membershipId);

        return Ok(result);
    }

    [HttpPost("use")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult>
        UseMembership(
            UseMembershipDto request)
    {
        var userId =
            GetAuthenticatedUserId();

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

    private int GetAuthenticatedUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}