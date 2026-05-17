using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.Application.Features.Appointments.Interfaces;

public interface IAppointmentService
{
    Task<AppointmentResponseDto> CreateAsync(int clientUserId,CreateAppointmentDto request);
    Task<List<AppointmentResponseDto>>GetMyAppointmentsAsync(int userId);
    Task<List<AppointmentResponseDto>>GetTherapistAppointmentsAsync(int therapistUserId);
    Task UpdateStatusAsync(int therapistUserId,UpdateAppointmentStatusDto request);
    Task CancelAppointmentAsync(int clientUserId,int appointmentId,CancelAppointmentDto request);
    Task<TherapistStatsDto> GetTherapistStatsAsync(int therapistUserId);
    Task AddAppointmentNoteAsync(int therapistUserId, CreateAppointmentNoteDto request);
    Task<AppointmentNoteResponseDto?>GetAppointmentNoteAsync(int therapistUserId, int appointmentId);
    Task<ClientDashboardDto>GetClientDashboardAsync(int clientUserId);
    Task UpdateMeetingLinkAsync(int therapistUserId, int appointmentId,UpdateMeetingLinkDto request);
}