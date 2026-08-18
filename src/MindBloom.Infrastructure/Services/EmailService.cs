using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Configuration;

namespace MindBloom.Infrastructure.Services;

public sealed class EmailService : IEmailService
{
    private readonly SmtpSettings
        _settings;

    public EmailService(
        IOptions<SmtpSettings> settings)
    {
        _settings =
            settings.Value;
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
    }
}