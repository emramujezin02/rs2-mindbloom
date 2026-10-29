using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Services;
using MindBloom.Infrastructure.Configuration;
using Moq;

namespace MindBloom.UnitTests.Therapists;

public sealed partial class PublicTherapistVisibilityTests
{
    [Theory]
    [InlineData(AppointmentStatus.Accepted, "none", true)]
    [InlineData(AppointmentStatus.Completed, "none", true)]
    [InlineData(AppointmentStatus.Pending, "none", false)]
    [InlineData(AppointmentStatus.Rejected, "none", false)]
    [InlineData(AppointmentStatus.Cancelled, "none", false)]
    [InlineData(AppointmentStatus.Accepted, "client", false)]
    [InlineData(AppointmentStatus.Accepted, "therapist", false)]
    [InlineData(AppointmentStatus.Accepted, "appointment", false)]
    public async Task BasicClientProfile_RequiresNondeletedAcceptedOrCompletedRelationship(
        AppointmentStatus status, string deletedEntity, bool allowed)
    {
        await using var db = CreateContext();
        var (therapist, client) = await SeedAsync(db);
        client.User.Email = "client@test.local";
        client.User.PhoneNumber = "123";
        client.IsDeleted = deletedEntity == "client";
        therapist.IsDeleted = deletedEntity == "therapist";
        db.Appointments.Add(new Appointment
        {
            ClientId = client.Id, TherapistId = therapist.Id, Status = status,
            StartUtc = DateTime.UtcNow.AddDays(1), EndUtc = DateTime.UtcNow.AddDays(1).AddHours(1),
            IsDeleted = deletedEntity == "appointment"
        });
        await db.SaveChangesAsync();
        var service = new TherapistService(db,
            Mock.Of<IWebHostEnvironment>(), Mock.Of<IGeocodingService>(), Mock.Of<ISecurityAuditService>(),
            new TherapistClientAccessService(db), Options.Create(new UploadSettings()));

        if (!allowed)
        {
            await Assert.ThrowsAsync<NotFoundException>(() => service.GetClientProfileAsync(therapist.UserId, client.Id));
        }
        else
        {
            var profile = await service.GetClientProfileAsync(therapist.UserId, client.Id);
            Assert.Equal(client.Id, profile.ClientId);
            Assert.Equal("Test Client", profile.FullName);
            Assert.Equal(client.User.Email, profile.Email);
            Assert.Equal(client.User.PhoneNumber, profile.PhoneNumber);
        }
        Assert.Empty(db.AppointmentStatusAudits);
        Assert.Equal(status, db.Appointments.Single().Status);
    }
}
