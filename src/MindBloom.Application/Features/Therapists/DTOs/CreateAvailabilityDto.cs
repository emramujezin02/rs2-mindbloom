namespace MindBloom.Application.Features.Therapists.DTOs;

public class CreateAvailabilityDto
{
    public DayOfWeek DayOfWeek { get; set; }

    public TimeSpan StartTime { get; set; }

    public TimeSpan EndTime { get; set; }
}