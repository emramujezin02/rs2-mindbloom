namespace MindBloom.Application.Features.Users.DTOs;

public class UpdateUserSettingsDto
{
    public bool NotificationsEnabled { get; set; }

    public bool ShowProfilePublicly { get; set; }

    public bool ShareMoodAndEmotionsWithTherapists
    {
        get;
        set;
    }
}