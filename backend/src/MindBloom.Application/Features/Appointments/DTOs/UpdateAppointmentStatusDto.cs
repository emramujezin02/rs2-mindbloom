using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Appointments.DTOs;

public class UpdateAppointmentStatusDto
{
    public AppointmentStatus Status { get; set; }
    public int AppointmentId {  get; set; }
}