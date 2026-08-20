using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Shared.Constants;
using MindBloom.API.Idempotency;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService
        _paymentService;

    public PaymentsController(
        IPaymentService paymentService)
    {
        _paymentService =
            paymentService;
    }

    [HttpPost("create-intent")]
    [RequireIdempotency]
    public async Task<IActionResult>
        CreateIntent(
            CreatePaymentIntentDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _paymentService
                .CreatePaymentIntentAsync(
                    userId,
                    request);

        return Ok(result);
    }

    [HttpPost("confirm")]
    public async Task<IActionResult>
        Confirm(
            ConfirmPaymentDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        await _paymentService
            .ConfirmPaymentAsync(
                userId,
                request);

        return NoContent();
    }

    [HttpGet("mine")]
    public async Task<IActionResult>
        GetMyPayments()
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _paymentService
                .GetMyPaymentsAsync(
                    userId);

        return Ok(result);
    }

    [HttpGet("{paymentId}/receipt")]
    public async Task<IActionResult>
        GetReceipt(
            int paymentId)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _paymentService
                .GetReceiptAsync(
                    paymentId,
                    userId);

        return Ok(result);
    }

    private int GetAuthenticatedUserId()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}