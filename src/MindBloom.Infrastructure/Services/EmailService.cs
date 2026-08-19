using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Configuration;
using Microsoft.Extensions.Logging;

namespace MindBloom.Infrastructure.Services;

public sealed class EmailService : IEmailService
{
    private static readonly EventId
    EmailSentEvent =
        new(
            3700,
            "EmailSent");

    private readonly SmtpSettings
        _settings;

    private readonly ILogger<EmailService>
        _logger;

    public EmailService(
        IOptions<SmtpSettings> settings,
        ILogger<EmailService> logger)
    {
        _settings =
            settings.Value;

        _logger =
            logger;
    }

    public async Task SendAsync(
        string to,
        string subject,
        string body)
    {
        if (string.IsNullOrWhiteSpace(to))
        {
            throw new ArgumentException(
                "Recipient email address is required.",
                nameof(to));
        }

        if (string.IsNullOrWhiteSpace(subject))
        {
            throw new ArgumentException(
                "Email subject is required.",
                nameof(subject));
        }

        if (string.IsNullOrWhiteSpace(body))
        {
            throw new ArgumentException(
                "Email body is required.",
                nameof(body));
        }

        using var smtpClient =
            new SmtpClient(
                _settings.Host,
                _settings.Port)
            {
                Credentials =
                    new NetworkCredential(
                        _settings.Username,
                        _settings.Password),

                EnableSsl =
                    _settings.EnableSsl
            };

        using var mailMessage =
            new MailMessage
            {
                From =
                    new MailAddress(
                        _settings.Username),

                Subject =
                    subject,

                Body =
                    body,

                IsBodyHtml =
                    false
            };

        mailMessage.To.Add(to);

        await smtpClient
            .SendMailAsync(mailMessage);

        _logger.LogInformation(
    EmailSentEvent,
    "Email sent successfully. Module: {Module}, Provider: {Provider}, Port: {Port}, SslEnabled: {SslEnabled}.",
    "Email",
    "SMTP",
    _settings.Port,
    _settings.EnableSsl);
    }
}