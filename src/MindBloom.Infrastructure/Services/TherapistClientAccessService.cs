using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class TherapistClientAccessService
    : ITherapistClientAccessService
{
    private readonly ApplicationDbContext
        _context;

    public TherapistClientAccessService(
        ApplicationDbContext context)
    {
        _context =
            context;
    }

    public async Task<bool> HasRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken =
            default)
    {
        var therapistId =
            await GetTherapistIdAsync(
                therapistUserId,
                cancellationToken);

        if (!therapistId.HasValue)
        {
            return false;
        }

        return await _context.Appointments
            .AsNoTracking()
            .AnyAsync(
                appointment =>
                    !appointment.IsDeleted &&
                    appointment.TherapistId ==
                        therapistId.Value &&
                    appointment.ClientId ==
                        clientId &&
                    (
                        appointment.Status ==
                            AppointmentStatus.Accepted ||
                        appointment.Status ==
                            AppointmentStatus.Completed
                    ),
                cancellationToken);
    }

    public async Task<bool>
        HasActiveRelationshipAsync(
            int therapistUserId,
            int clientId,
            CancellationToken cancellationToken =
                default)
    {
        var therapistId =
            await GetTherapistIdAsync(
                therapistUserId,
                cancellationToken);

        if (!therapistId.HasValue)
        {
            return false;
        }

        var now =
            DateTime.UtcNow;

        /*
         * Accepted termin koji još traje
         * ili tek treba početi predstavlja
         * aktivni profesionalni odnos.
         */
        var hasAcceptedAppointment =
            await _context.Appointments
                .AsNoTracking()
                .AnyAsync(
                    appointment =>
                        !appointment.IsDeleted &&
                        appointment.TherapistId ==
                            therapistId.Value &&
                        appointment.ClientId ==
                            clientId &&
                        appointment.Status ==
                            AppointmentStatus.Accepted &&
                        appointment.EndUtc >
                            now,
                    cancellationToken);

        if (hasAcceptedAppointment)
        {
            return true;
        }

        /*
         * Aktivno članstvo također predstavlja
         * aktivan profesionalni odnos, čak i
         * između dva termina.
         */
        return await _context.ClientMemberships
            .AsNoTracking()
            .AnyAsync(
                membership =>
                    !membership.IsDeleted &&
                    membership.ClientId ==
                        clientId &&
                    membership.TherapistId ==
                        therapistId.Value &&
                    membership.IsActive &&
                    membership.RemainingSessions >
                        0 &&
                    (
                        membership.ExpiresAtUtc ==
                            null ||
                        membership.ExpiresAtUtc >
                            now
                    ),
                cancellationToken);
    }

    public async Task EnsureRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken =
            default)
    {
        await EnsureParticipantsExistAsync(
            therapistUserId,
            clientId,
            cancellationToken);

        var hasRelationship =
            await HasRelationshipAsync(
                therapistUserId,
                clientId,
                cancellationToken);

        if (!hasRelationship)
        {
            throw new NotFoundException(
                "Client not found or is not available to this therapist.");
        }
    }

    public async Task EnsureActiveRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken =
            default)
    {
        await EnsureParticipantsExistAsync(
            therapistUserId,
            clientId,
            cancellationToken);

        var hasActiveRelationship =
            await HasActiveRelationshipAsync(
                therapistUserId,
                clientId,
                cancellationToken);

        if (!hasActiveRelationship)
        {
            throw new NotFoundException(
                "Client data is not available to this therapist.");
        }
    }

    private async Task<int?>
        GetTherapistIdAsync(
            int therapistUserId,
            CancellationToken cancellationToken)
    {
        return await _context.Therapists
            .AsNoTracking()
            .Where(x =>
                x.UserId ==
                    therapistUserId &&
                !x.IsDeleted)
            .Select(x =>
                (int?)x.Id)
            .FirstOrDefaultAsync(
                cancellationToken);
    }

    private async Task
        EnsureParticipantsExistAsync(
            int therapistUserId,
            int clientId,
            CancellationToken cancellationToken)
    {
        var therapistExists =
            await _context.Therapists
                .AsNoTracking()
                .AnyAsync(
                    x =>
                        x.UserId ==
                            therapistUserId &&
                        !x.IsDeleted,
                    cancellationToken);

        if (!therapistExists)
        {
            throw new NotFoundException(
                "Therapist not found.");
        }

        var clientExists =
            await _context.Clients
                .AsNoTracking()
                .AnyAsync(
                    x =>
                        x.Id ==
                            clientId &&
                        !x.IsDeleted,
                    cancellationToken);

        if (!clientExists)
        {
            throw new NotFoundException(
                "Client not found.");
        }
    }
}