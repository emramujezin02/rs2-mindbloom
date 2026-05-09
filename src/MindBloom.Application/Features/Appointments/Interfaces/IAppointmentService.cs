using MindBloom.Application.Features.Appointments.DTOs;

namespace MindBloom.Application.Features.Appointments.Interfaces;

public interface IAppointmentService
{
    Task<AppointmentResponseDto> CreateAsync(
        int clientUserId,
        CreateAppointmentDto request);

    Task<List<AppointmentResponseDto>>
        GetMyAppointmentsAsync(int userId);



    Task<List<AppointmentResponseDto>>
    GetTherapistAppointmentsAsync(int therapistUserId);

    Task UpdateStatusAsync(
        int therapistUserId,
        UpdateAppointmentStatusDto request);
}