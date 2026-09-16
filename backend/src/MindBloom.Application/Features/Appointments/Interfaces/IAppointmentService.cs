using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Therapists.DTOs;

using MindBloom.Application.Common.Models;

namespace MindBloom.Application.Features.Appointments.Interfaces;

public interface IAppointmentService
{
    Task<AppointmentResponseDto> CreateAsync(
        int clientUserId,
        CreateAppointmentDto request);

    Task<PagedResponse<AppointmentResponseDto>> GetMyAppointmentsAsync(
        int userId,
        int pageNumber,
        int pageSize,
        string? status,
        DateTime? fromUtc,
        DateTime? toUtc);

    Task<AppointmentResponseDto> GetClientAppointmentDetailsAsync(
        int clientUserId,
        int appointmentId);

    Task<PagedResponse<AppointmentResponseDto>> GetTherapistAppointmentsAsync(
        int therapistUserId,
        int pageNumber,
        int pageSize,
        string? status,
        DateTime? fromUtc,
        DateTime? toUtc);

    Task UpdateStatusAsync(
        int therapistUserId,
        UpdateAppointmentStatusDto request);

    Task CancelAppointmentAsync(
        int clientUserId,
        int appointmentId,
        CancelAppointmentDto request);

    Task<TherapistStatsDto> GetTherapistStatsAsync(
        int therapistUserId);

    Task AddAppointmentNoteAsync(
        int therapistUserId,
        CreateAppointmentNoteDto request);

    Task<AppointmentNoteResponseDto?> GetAppointmentNoteAsync(
        int therapistUserId,
        int appointmentId);

    Task<ClientDashboardDto> GetClientDashboardAsync(
        int clientUserId);

    Task UpdateMeetingLinkAsync(
        int therapistUserId,
        int appointmentId,
        UpdateMeetingLinkDto request);

    Task<List<OccupiedAppointmentSlotDto>> GetOccupiedSlotsAsync(
        int therapistId,
        DateTime date);
}
