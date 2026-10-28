using MindBloom.Application.Common.Exceptions;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using System.Diagnostics.CodeAnalysis;

namespace MindBloom.Application.Common.BusinessRules;

public static class AppointmentBookingRules
{
    public static void EnsureTherapistEligible([NotNull] Therapist? therapist)
    {
        if (therapist is null)
            throw new NotFoundException("Therapist not found.");

        if (therapist.IsDeleted ||
            therapist.VerificationStatus != TherapistVerificationStatus.Approved ||
            therapist.User is null || !therapist.User.IsActive || therapist.User.IsBlocked)
            throw new BusinessException("This therapist is not available for booking.");
    }
}
