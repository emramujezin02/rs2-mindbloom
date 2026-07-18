using System.Net;
using System.Net.Mail;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Services;

public sealed class EmailService : IEmailService
{
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

        var emailUsername =
            Environment.GetEnvironmentVariable(
                "EMAIL_USERNAME");

        var emailPassword =
            Environment.GetEnvironmentVariable(
                "EMAIL_PASSWORD");

        if (string.IsNullOrWhiteSpace(emailUsername))
        {
            throw new InvalidOperationException(
                "Environment variable 'EMAIL_USERNAME' is required.");
        }

        if (string.IsNullOrWhiteSpace(emailPassword))
        {
            throw new InvalidOperationException(
                "Environment variable 'EMAIL_PASSWORD' is required.");
        }

        using var smtpClient = new SmtpClient(
            "smtp.gmail.com",
            587)
        {
            Credentials = new NetworkCredential(
                emailUsername,
                emailPassword),

            EnableSsl = true
        };

        using var mailMessage = new MailMessage
        {
            From = new MailAddress(emailUsername),
            Subject = subject,
            Body = body,
            IsBodyHtml = false
        };

        mailMessage.To.Add(to);

        await smtpClient.SendMailAsync(mailMessage);
    }
}