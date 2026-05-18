using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(
        IPaymentService paymentService)
    {
        _paymentService = paymentService;
    }

    [Authorize(Roles = "Client")]
    [HttpPost("create-intent")]
    public async Task<IActionResult>
        CreateIntent(
            CreatePaymentIntentDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                    .Value);

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
        await _paymentService
            .ConfirmPaymentAsync(request);

        return Ok(new
        {
            message = "Payment confirmed."
        });
    }

    [Authorize(Roles = "Client")]
    [HttpGet("mine")]
    public async Task<IActionResult>
    GetMyPayments()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _paymentService
                .GetMyPaymentsAsync(
                    userId);

        return Ok(result);
    }
}