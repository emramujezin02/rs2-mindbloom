using System.Linq.Expressions;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;

namespace MindBloom.Infrastructure.Persistence.Queries;

public static class TherapistVisibility
{
    public static readonly Expression<Func<Therapist, bool>> PubliclyVisible = therapist =>
        !therapist.IsDeleted &&
        therapist.VerificationStatus == TherapistVerificationStatus.Approved &&
        therapist.User.IsActive &&
        !therapist.User.IsBlocked &&
        (therapist.User.Settings == null || therapist.User.Settings.ShowProfilePublicly);
}
