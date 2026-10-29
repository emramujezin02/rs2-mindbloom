using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Appointments.DTOs;

public class UpdateAppointmentStatusDto
{
    public const int MaximumReasonLength = 500;

    public AppointmentStatus Status { get; set; }
    public int AppointmentId {  get; set; }
    public string? Reason { get; set; }
}
