using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Services;

public sealed class NoOpEmailService
    : IEmailService
{
    public Task SendAsync(
        string to,
        string subject,
        string body)
    {
        return Task.CompletedTask;
    }
}