namespace MindBloom.Application.Features.Therapists.DTOs;

public class AvailabilityResponseDto
{
    public int Id { get; set; }

    public DayOfWeek DayOfWeek { get; set; }

    public TimeSpan StartTime { get; set; }

    public TimeSpan EndTime { get; set; }
}