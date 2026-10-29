using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Infrastructure.Services;

public partial class AppointmentService
{
    private const string ExpiredRequestReason =
        "Appointment request expired because the therapist did not respond before the scheduled end time.";

    private async Task AutoCompleteAppointmentsAsync()
    {
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        var ids = await _context.Appointments.AsNoTracking()
            .Where(x => x.EndUtc <= nowUtc &&
                (x.Status == AppointmentStatus.Accepted || x.Status == AppointmentStatus.Pending))
            .OrderBy(x => x.Id).Select(x => x.Id).ToListAsync();

        // Each appointment is atomic. A failure stops the batch; committed items are safe to retry.
        foreach (var id in ids)
        {
            var strategy = _context.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                await using var statusLock = await AppointmentStatusLock.AcquireAsync(_context, id);
                await using var transaction = _context.Database.IsRelational()
                    ? await _context.Database.BeginTransactionAsync() : null;
                try
                {
                    var appointment = await _context.Appointments
                        .Include(x => x.Client).ThenInclude(x => x.User)
                        .Include(x => x.Therapist).ThenInclude(x => x.User)
                        .SingleOrDefaultAsync(x => x.Id == id);
                    if (appointment != null)
                        await _context.Entry(appointment).ReloadAsync();

                    // Re-check after acquiring the lock: the initial list is only a candidate list.
                    if (appointment == null || appointment.EndUtc > nowUtc ||
                        appointment.Status is not (AppointmentStatus.Accepted or AppointmentStatus.Pending))
                    {
                        if (transaction != null) await transaction.CommitAsync();
                        return;
                    }

                    var previousStatus = appointment.Status;
                    var completed = previousStatus == AppointmentStatus.Accepted;
                    var nextStatus = completed ? AppointmentStatus.Completed : AppointmentStatus.Rejected;
                    if (!IsValidStatusTransition(previousStatus, nextStatus))
                        throw new InvalidOperationException("Invalid automatic appointment status transition.");
                    var reason = completed ? "Appointment automatically completed after its scheduled end time."
                        : ExpiredRequestReason;

                    appointment.Status = nextStatus;
                    appointment.UpdatedAtUtc = nowUtc;
                    _context.AppointmentStatusAudits.Add(new AppointmentStatusAudit
                    {
                        AppointmentId = id, ChangedByUserId = null, PreviousStatus = previousStatus,
                        NewStatus = nextStatus, Action = completed ? "AutomaticCompletion" : "AutomaticExpiration",
                        Reason = reason, ChangedAtUtc = nowUtc
                    });

                    if (completed)
                    {
                        await _membershipService.FinalizeAppointmentUsageAsync(id,
                            "Membership session consumed after automatic appointment completion.");
                        await _outboxWriter.EnqueueAsync(new AppointmentCompletedEvent
                        {
                            CorrelationId = Guid.NewGuid(), TimestampUtc = nowUtc,
                            AppointmentId = id, ClientId = appointment.ClientId,
                            ClientUserId = appointment.Client.UserId, TherapistId = appointment.TherapistId,
                            TherapistUserId = appointment.Therapist.UserId,
                            StartUtc = appointment.StartUtc, EndUtc = appointment.EndUtc,
                            CompletedByUserId = null, AppointmentType = appointment.Type.ToString(),
                            Price = appointment.Price, IsPaid = appointment.IsPaid
                        }, IntegrationEventRoutingKeys.AppointmentCompleted);
                    }
                    else
                    {
                        await _outboxWriter.EnqueueAsync(new AppointmentRejectedEvent
                        {
                            CorrelationId = Guid.NewGuid(), TimestampUtc = nowUtc,
                            AppointmentId = id, ClientId = appointment.ClientId,
                            ClientUserId = appointment.Client.UserId,
                            ClientEmail = appointment.Client.User.Email ?? string.Empty,
                            ClientName = BuildFullName(appointment.Client.User.FirstName, appointment.Client.User.LastName),
                            TherapistId = appointment.TherapistId, TherapistUserId = appointment.Therapist.UserId,
                            TherapistName = BuildFullName(appointment.Therapist.User.FirstName, appointment.Therapist.User.LastName),
                            StartUtc = appointment.StartUtc, EndUtc = appointment.EndUtc, Reason = reason
                        }, IntegrationEventRoutingKeys.AppointmentRejected);
                    }

                    await _context.SaveChangesAsync();
                    if (transaction != null) await transaction.CommitAsync();
                }
                catch
                {
                    if (transaction != null) await transaction.RollbackAsync();
                    _context.ChangeTracker.Clear();
                    throw;
                }
            });
        }
    }
}
