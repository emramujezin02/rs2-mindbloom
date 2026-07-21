using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
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

    [Authorize(Roles = "Client")]
    [HttpPost("create-intent")]
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

    [Authorize(Roles = "Client")]
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

    [Authorize(Roles = "Client")]
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

    [Authorize(Roles = "Client")]
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