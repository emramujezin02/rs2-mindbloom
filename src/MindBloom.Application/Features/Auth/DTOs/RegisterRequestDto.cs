namespace MindBloom.Application.Features.Auth.DTOs;

public class RegisterRequestDto
{
    public string FirstName { get; set; }
        = string.Empty;

    public string LastName { get; set; }
        = string.Empty;

    public string Email { get; set; }
        = string.Empty;

    public string Username { get; set; }
        = string.Empty;

    public string Password { get; set; }
        = string.Empty;

    public DateTime DateOfBirth { get; set; }

    public string Gender { get; set; }
        = string.Empty;

    public bool AcceptPrivacyPolicy { get; set; }

    public string PrivacyPolicyVersion { get; set; }
        = string.Empty;

    public bool AcceptTermsOfService { get; set; }

    public string TermsOfServiceVersion { get; set; }
        = string.Empty;
}