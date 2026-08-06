using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using System.Security.Claims;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
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
    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
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
    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
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
    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
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
    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
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
    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
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

        return NoContent();
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