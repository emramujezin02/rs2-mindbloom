using FluentValidation;
using MindBloom.Shared.Constants;
using MindBloom.Application.Features.Auth.DTOs;

namespace MindBloom.Application.Features.Auth.Validators;

public static class AuthValidationRules
{
    public const int MaximumEmailLength = 254;

    public const int MinimumPasswordLength = 8;

    public const int MaximumPasswordLength = 128;

    public const int MaximumNameLength = 100;

    public const int MinimumUsernameLength = 3;

    public const int MaximumUsernameLength = 50;

    public const int VerificationCodeLength = 6;

    public const int MaximumTokenLength = 4096;

    public static IRuleBuilderOptions<T, string>
        ValidEmail<T>(
            this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .NotEmpty()
            .WithMessage(
                "Email is required.")
            .MaximumLength(
                MaximumEmailLength)
            .WithMessage(
                $"Email may contain at most {MaximumEmailLength} characters.")
            .EmailAddress()
            .WithMessage(
                "Email address is not valid.");
    }

    public static IRuleBuilderOptions<T, string>
        ValidPassword<T>(
            this IRuleBuilder<T, string> ruleBuilder,
            string fieldName = "Password")
    {
        return ruleBuilder
            .NotEmpty()
            .WithMessage(
                $"{fieldName} is required.")
            .MinimumLength(
                MinimumPasswordLength)
            .WithMessage(
                $"{fieldName} must contain at least {MinimumPasswordLength} characters.")
            .MaximumLength(
                MaximumPasswordLength)
            .WithMessage(
                $"{fieldName} may contain at most {MaximumPasswordLength} characters.")
            .Matches("[A-Z]")
            .WithMessage(
                $"{fieldName} must contain at least one uppercase letter.")
            .Matches("[a-z]")
            .WithMessage(
                $"{fieldName} must contain at least one lowercase letter.")
            .Matches("[0-9]")
            .WithMessage(
                $"{fieldName} must contain at least one number.")
            .Matches(@"[^a-zA-Z0-9]")
            .WithMessage(
                $"{fieldName} must contain at least one special character.");
    }

    public static IRuleBuilderOptions<T, string>
        ValidVerificationCode<T>(
            this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .NotEmpty()
            .WithMessage(
                "Verification code is required.")
            .Length(
                VerificationCodeLength)
            .WithMessage(
                $"Verification code must contain exactly {VerificationCodeLength} digits.")
            .Matches(@"^\d{6}$")
            .WithMessage(
                "Verification code may contain digits only.");
    }
}

public sealed class RegisterRequestDtoValidator
    : AbstractValidator<RegisterRequestDto>
{
    public RegisterRequestDtoValidator()
    {
        RuleFor(x => x.FirstName)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "First name is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumNameLength)
            .WithMessage(
                $"First name may contain at most {AuthValidationRules.MaximumNameLength} characters.")
            .Matches(
                @"^[\p{L}\p{M}][\p{L}\p{M}' -]*$")
            .WithMessage(
                "First name contains invalid characters.");

        RuleFor(x => x.Gender)
    .Cascade(
        CascadeMode.Stop)
    .NotEmpty()
    .WithMessage(
        "Gender is required.")
    .Must(value =>
    {
        if (string.IsNullOrWhiteSpace(
                value))
        {
            return false;
        }

        var normalized =
            value.Trim();

        return normalized.Equals(
                   "Male",
                   StringComparison
                       .OrdinalIgnoreCase)
               ||
               normalized.Equals(
                   "Female",
                   StringComparison
                       .OrdinalIgnoreCase)
               ||
               normalized.Equals(
                   "Other",
                   StringComparison
                       .OrdinalIgnoreCase);
    })
    .WithMessage(
        "Gender must be Male, Female or Other.");

        RuleFor(x => x.LastName)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Last name is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumNameLength)
            .WithMessage(
                $"Last name may contain at most {AuthValidationRules.MaximumNameLength} characters.")
            .Matches(
                @"^[\p{L}\p{M}][\p{L}\p{M}' -]*$")
            .WithMessage(
                "Last name contains invalid characters.");

        RuleFor(x => x.Email)
            .ValidEmail();

        RuleFor(x => x.Username)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Username is required.")
            .MinimumLength(
                AuthValidationRules
                    .MinimumUsernameLength)
            .WithMessage(
                $"Username must contain at least {AuthValidationRules.MinimumUsernameLength} characters.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumUsernameLength)
            .WithMessage(
                $"Username may contain at most {AuthValidationRules.MaximumUsernameLength} characters.")
            .Matches(@"^[a-zA-Z0-9._-]+$")
            .WithMessage(
                "Username may contain letters, numbers, dots, underscores and hyphens only.");

        RuleFor(x => x.Password)
            .ValidPassword();

        RuleFor(x => x.DateOfBirth)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Date of birth is required.")
            .Must(date =>
                date.Date <= DateTime.UtcNow.Date)
            .WithMessage(
                "Date of birth cannot be in the future.")
            .Must(date =>
                date.Date >=
                DateTime.UtcNow.Date.AddYears(-120))
            .WithMessage(
                "Date of birth is not valid.");

        RuleFor(x =>
        x.AcceptPrivacyPolicy)
    .Equal(true)
    .WithMessage(
        "Privacy policy must be accepted.");

        RuleFor(x =>
                x.PrivacyPolicyVersion)
            .NotEmpty()
            .WithMessage(
                "Privacy policy version is required.")
            .Equal(
                ConsentDocumentConstants
                    .PrivacyPolicyVersion)
            .WithMessage(
                "The privacy policy version is no longer current.");

        RuleFor(x =>
                x.AcceptTermsOfService)
            .Equal(true)
            .WithMessage(
                "Terms of service must be accepted.");

        RuleFor(x =>
                x.TermsOfServiceVersion)
            .NotEmpty()
            .WithMessage(
                "Terms of service version is required.")
            .Equal(
                ConsentDocumentConstants
                    .TermsOfServiceVersion)
            .WithMessage(
                "The terms of service version is no longer current.");
    }
}

public sealed class LoginRequestDtoValidator
    : AbstractValidator<LoginRequestDto>
{
    public LoginRequestDtoValidator()
    {
        RuleFor(x => x.Email)
            .ValidEmail();

        RuleFor(x => x.Password)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Password is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumPasswordLength)
            .WithMessage(
                $"Password may contain at most {AuthValidationRules.MaximumPasswordLength} characters.");
    }
}

public sealed class ChangePasswordDtoValidator
    : AbstractValidator<ChangePasswordDto>
{
    public ChangePasswordDtoValidator()
    {
        RuleFor(x => x.CurrentPassword)
            .Cascade(
                CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Current password is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumPasswordLength)
            .WithMessage(
                $"Current password may contain at most {AuthValidationRules.MaximumPasswordLength} characters.");

        RuleFor(x => x.NewPassword)
            .ValidPassword(
                "New password");

        RuleFor(x => x.NewPassword)
            .NotEqual(x =>
                x.CurrentPassword)
            .WithMessage(
                "New password must be different from the current password.");

        RuleFor(x =>
                x.ConfirmNewPassword)
            .Cascade(
                CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "New password confirmation is required.")
            .Equal(x =>
                x.NewPassword)
            .WithMessage(
                "New password and confirmation do not match.");
    }
}

public sealed class ForgotPasswordDtoValidator
    : AbstractValidator<ForgotPasswordDto>
{
    public ForgotPasswordDtoValidator()
    {
        RuleFor(x => x.Email)
            .ValidEmail();
    }
}

public sealed class ResetPasswordDtoValidator
    : AbstractValidator<ResetPasswordDto>
{
    public ResetPasswordDtoValidator()
    {
        RuleFor(x => x.Email)
            .ValidEmail();

        RuleFor(x => x.Token)
            .Cascade(
                CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Password reset token is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumTokenLength)
            .WithMessage(
                $"Password reset token may contain at most {AuthValidationRules.MaximumTokenLength} characters.");

        RuleFor(x => x.NewPassword)
            .ValidPassword(
                "New password");
    }
}

public sealed class DeleteAccountRequestDtoValidator
    : AbstractValidator<DeleteAccountRequestDto>
{
    public DeleteAccountRequestDtoValidator()
    {
        RuleFor(x => x.Password)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Password is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumPasswordLength)
            .WithMessage(
                $"Password may contain at most {AuthValidationRules.MaximumPasswordLength} characters.");
    }
}

public sealed class RefreshTokenRequestDtoValidator
    : AbstractValidator<RefreshTokenRequestDto>
{
    public RefreshTokenRequestDtoValidator()
    {
        RuleFor(x => x.RefreshToken)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Refresh token is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumTokenLength)
            .WithMessage(
                $"Refresh token may contain at most {AuthValidationRules.MaximumTokenLength} characters.");
    }
}

public sealed class Verify2FADtoValidator
    : AbstractValidator<Verify2FADto>
{
    public Verify2FADtoValidator()
    {
        RuleFor(x => x.ChallengeToken)
            .Cascade(
                CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Two-factor challenge token is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumTokenLength)
            .WithMessage(
                $"Two-factor challenge token may contain at most {AuthValidationRules.MaximumTokenLength} characters.");

        RuleFor(x => x.Code)
            .ValidVerificationCode();
    }
}

public sealed class
    ChangeTwoFactorSettingDtoValidator
    : AbstractValidator<
        ChangeTwoFactorSettingDto>
{
    public ChangeTwoFactorSettingDtoValidator()
    {
        RuleFor(x =>
                x.CurrentPassword)
            .Cascade(
                CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Current password is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumPasswordLength)
            .WithMessage(
                $"Current password may contain at most {AuthValidationRules.MaximumPasswordLength} characters.");
    }
}

public sealed class VerifyEmailDtoValidator
    : AbstractValidator<VerifyEmailDto>
{
    public VerifyEmailDtoValidator()
    {
        RuleFor(x => x.Email)
            .ValidEmail();

        RuleFor(x => x.Token)
            .Cascade(CascadeMode.Stop)
            .NotEmpty()
            .WithMessage(
                "Email verification token is required.")
            .MaximumLength(
                AuthValidationRules
                    .MaximumTokenLength)
            .WithMessage(
                $"Email verification token may contain at most {AuthValidationRules.MaximumTokenLength} characters.");
    }
}

public sealed class SendEmailVerificationCodeDtoValidator
    : AbstractValidator<SendEmailVerificationCodeDto>
{
    public SendEmailVerificationCodeDtoValidator()
    {
        RuleFor(x => x.Email)
            .ValidEmail();
    }
}

public sealed class VerifyEmailCodeDtoValidator
    : AbstractValidator<VerifyEmailCodeDto>
{
    public VerifyEmailCodeDtoValidator()
    {
        RuleFor(x => x.Email)
            .ValidEmail();

        RuleFor(x => x.Code)
            .ValidVerificationCode();
    }
}