using System.Text;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.NotificationsWorker.Services;

public sealed class EmailMessageBodyBuilder
{
    public string Build(EmailNotificationMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);

        if (!string.IsNullOrWhiteSpace(message.Body))
        {
            return message.Body;
        }

        if (string.IsNullOrWhiteSpace(message.TemplateName))
        {
            throw new InvalidOperationException(
                "Email message must contain either Body or TemplateName.");
        }

        var builder = new StringBuilder();

        if (!string.IsNullOrWhiteSpace(message.RecipientName))
        {
            builder.AppendLine($"Hello {message.RecipientName},");
            builder.AppendLine();
        }
        else
        {
            builder.AppendLine("Hello,");
            builder.AppendLine();
        }

        builder.AppendLine(
            GetTemplateIntroduction(message));

        if (message.TemplateData.Count > 0)
        {
            builder.AppendLine();

            foreach (var item in message.TemplateData)
            {
                if (string.IsNullOrWhiteSpace(item.Value))
                {
                    continue;
                }

                builder.AppendLine(
                    $"{FormatKey(item.Key)}: {item.Value}");
            }
        }

        builder.AppendLine();
        builder.AppendLine("Kind regards,");
        builder.AppendLine("MindBloom");

        return builder.ToString();
    }

    private static string GetTemplateIntroduction(
        EmailNotificationMessage message)
    {
        var templateName =
            message.TemplateName?
                .Trim()
                .ToLowerInvariant()
            ?? string.Empty;

        return templateName switch
        {
            "appointment-approved" =>
                "Your appointment has been approved.",

            "appointment-rejected" =>
                "Your appointment request has been rejected.",

            "appointment-cancelled" =>
                "Your appointment has been cancelled.",

            "appointment-reminder" =>
                "This is a reminder about your upcoming appointment.",

            "payment-completed" =>
                "Your payment has been completed successfully.",

            "payment-failed" =>
                "Unfortunately, your payment could not be completed.",

            "membership-activated" =>
                "Your MindBloom membership has been activated.",

            "membership-expiring" =>
                "Your MindBloom membership will expire soon.",

            "membership-expired" =>
                "Your MindBloom membership has expired.",

            "password-reset" =>
                "A password reset was requested for your account.",

            "email-verification" =>
                "Please verify your email address.",

            "two-factor-code" =>
                "Your two-factor authentication code is ready.",

            "therapist-verification-approved" =>
                "Your therapist profile has been approved.",

            "therapist-verification-rejected" =>
                "Your therapist verification request has been rejected.",

            "workshop-registration-confirmed" =>
                "Your workshop registration has been confirmed.",

            "workshop-reminder" =>
                "This is a reminder about your upcoming workshop.",

            _ =>
                "You have received a new notification from MindBloom."
        };
    }

    private static string FormatKey(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
        {
            return "Information";
        }

        var builder = new StringBuilder();

        for (var index = 0; index < key.Length; index++)
        {
            var currentCharacter = key[index];

            if (index > 0 &&
                char.IsUpper(currentCharacter) &&
                !char.IsWhiteSpace(key[index - 1]))
            {
                builder.Append(' ');
            }

            builder.Append(currentCharacter);
        }

        var formattedKey = builder.ToString().Trim();

        return char.ToUpperInvariant(formattedKey[0]) +
               formattedKey[1..];
    }
}