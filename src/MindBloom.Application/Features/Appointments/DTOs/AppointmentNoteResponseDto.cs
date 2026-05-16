namespace MindBloom.Application.Features.Appointments.DTOs;

public class AppointmentNoteResponseDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public string Notes { get; set; }
        = string.Empty;

    public string ClientMood { get; set; }
        = string.Empty;

    public string Recommendations { get; set; }
        = string.Empty;

    public bool FollowUpNeeded { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}