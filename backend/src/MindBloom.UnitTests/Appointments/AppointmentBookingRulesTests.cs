using MindBloom.Application.Common.BusinessRules;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;

namespace MindBloom.UnitTests.Appointments;

public sealed class AppointmentBookingRulesTests
{
    [Theory]
    [InlineData(TherapistVerificationStatus.Pending)]
    [InlineData(TherapistVerificationStatus.RequiresChanges)]
    [InlineData(TherapistVerificationStatus.Rejected)]
    public void UnapprovedTherapistCannotBeBooked(TherapistVerificationStatus status)
    {
        var therapist = Eligible(); therapist.VerificationStatus = status;
        Assert.Throws<BusinessException>(() => AppointmentBookingRules.EnsureTherapistEligible(therapist));
    }

    [Theory]
    [InlineData("deleted")]
    [InlineData("inactive")]
    [InlineData("blocked")]
    [InlineData("missing-user")]
    public void InvalidAccountOrDeletedProfileCannotBeBooked(string state)
    {
        var therapist = Eligible();
        switch(state)
        {
            case "deleted": therapist.IsDeleted=true; break;
            case "inactive": therapist.User.IsActive=false; break;
            case "blocked": therapist.User.IsBlocked=true; break;
            case "missing-user": therapist.User=null!; break;
        }
        Assert.Throws<BusinessException>(() => AppointmentBookingRules.EnsureTherapistEligible(therapist));
    }

    [Fact]
    public void MissingTherapistReturnsNotFound() =>
        Assert.Throws<NotFoundException>(() => AppointmentBookingRules.EnsureTherapistEligible(null));

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void ApprovalAndActiveAccountAllowBookingWithoutRequiringPublicProfile(bool visible)
    {
        var therapist=Eligible(); therapist.User.Settings=new() {ShowProfilePublicly=visible};
        AppointmentBookingRules.EnsureTherapistEligible(therapist);
    }

    private static Therapist Eligible()=>new() {User=new() {IsActive=true},VerificationStatus=TherapistVerificationStatus.Approved};
}
