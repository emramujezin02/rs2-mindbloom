using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Validators;
using MindBloom.Domain.Enums;

namespace MindBloom.UnitTests.Appointments;

public sealed class AppointmentRejectionReasonTests
{
    [Theory]
    [InlineData(null, false)]
    [InlineData("", false)]
    [InlineData("   ", false)]
    [InlineData("abcd", false)]
    [InlineData("  abcd  ", false)]
    [InlineData("abcde", true)]
    [InlineData("  abcde  ", true)]
    [InlineData("A scheduling conflict", true)]
    [InlineData("Želim drugi termin", true)]
    public void Rejection_ValidatesTrimmedReason(string? reason, bool valid)
    {
        var result = new UpdateAppointmentStatusDtoValidator().Validate(new UpdateAppointmentStatusDto()
            { AppointmentId = 1, Status = AppointmentStatus.Rejected, Reason = reason });
        Assert.Equal(valid, result.IsValid);
    }

    [Theory]
    [InlineData(500, true)]
    [InlineData(501, false)]
    public void Rejection_UsesExistingCancellationLengthLimit(int length, bool valid) =>
        Assert.Equal(valid, new UpdateAppointmentStatusDtoValidator().Validate(new UpdateAppointmentStatusDto()
            { AppointmentId = 1, Status = AppointmentStatus.Rejected, Reason = new string('x', length) }).IsValid);

    [Theory]
    [InlineData(AppointmentStatus.Accepted)]
    [InlineData(AppointmentStatus.Completed)]
    public void OtherStatuses_DoNotRequireReason(AppointmentStatus status) =>
        Assert.True(new UpdateAppointmentStatusDtoValidator().Validate(new UpdateAppointmentStatusDto()
            { AppointmentId = 1, Status = status }).IsValid);
}
