namespace MindBloom.Application.Features.Auth.DTOs;

public sealed class ChangeTwoFactorSettingDto
{
    public string CurrentPassword { get; set; } =
        string.Empty;
}