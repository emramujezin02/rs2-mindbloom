using System.Net;
using System.Net.Mail;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.Infrastructure.Services;

public class EmailService : IEmailService
{
    public async Task SendAsync(
        string to,
        string subject,
        string body)
    {
        var smtpClient = new SmtpClient("smtp.gmail.com")
        {
            Port = 587,

            Credentials = new NetworkCredential(
                Environment.GetEnvironmentVariable("EMAIL_USERNAME"),
                Environment.GetEnvironmentVariable("EMAIL_PASSWORD")),

            EnableSsl = true
        };

        var mailMessage = new MailMessage
        {
            From = new MailAddress(
                Environment.GetEnvironmentVariable("EMAIL_USERNAME")!),

            Subject = subject,

            Body = body,

            IsBodyHtml = false
        };

        mailMessage.To.Add(to);

        await smtpClient.SendMailAsync(mailMessage);
    }
}