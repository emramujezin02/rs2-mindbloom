using System.Reflection;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Validators;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Appointments;

// Pure mapping/validation tests; no database, host, network or external provider.
public sealed class AppointmentCreateResponseTests
{
    [Theory]
    [InlineData(AppointmentType.Online)]
    [InlineData(AppointmentType.InPerson)]
    public void Creation_mapping_preserves_the_complete_existing_contract(AppointmentType type)
    {
        var (appointment, client, therapist) = Scenario(type);
        var response = Map(appointment, client, therapist);

        Assert.Equal(appointment.Id, response.Id);
        Assert.Equal(appointment.ClientId, response.ClientId);
        Assert.Equal(appointment.TherapistId, response.TherapistId);
        Assert.Equal("Synthetic Client", response.ClientName);
        Assert.Equal(client.User.Email, response.ClientEmail);
        Assert.Equal("Synthetic Therapist", response.TherapistName);
        Assert.Equal(appointment.Price, response.Price);
        Assert.Equal(appointment.StartUtc, response.StartUtc);
        Assert.Equal(DateTimeKind.Utc, response.StartUtc.Kind);
        Assert.Equal(appointment.EndUtc, response.EndUtc);
        Assert.Equal(DateTimeKind.Utc, response.EndUtc.Kind);
        Assert.Equal("Pending", response.Status);
        Assert.Equal(type.ToString(), response.Type);
        Assert.Equal(appointment.Notes, response.Notes);
        Assert.Equal(appointment.Location, response.Location);
        Assert.Null(response.PaymentId);
        Assert.False(response.CanAccessSession);
        Assert.Null(response.MeetingLink); // Pending must not disclose even a supplied link.
        Assert.Equal(type == AppointmentType.Online
            ? "The therapist must accept the appointment before the online session becomes available."
            : "This is an in-person appointment.", response.SessionAccessMessage);
        // Adding fields must trigger a deliberate contract review.
        Assert.Equal(17, typeof(AppointmentResponseDto).GetProperties().Length);
    }

    [Fact]
    public void Mapping_reserved_price_never_uses_a_changed_current_hourly_rate()
    {
        var (appointment, client, therapist) = Scenario(AppointmentType.Online);
        Assert.Equal(50.25m, Map(appointment, client, therapist).Price);
        therapist.HourlyRate = 99.75m;
        var response = Map(appointment, client, therapist);
        Assert.Equal(50.25m, response.Price);
        Assert.Equal(appointment.Price, response.Price);
        Assert.Equal(99.75m, therapist.HourlyRate);
    }

    [Fact]
    public void Optional_creation_fields_remain_null_without_fabricated_values()
    {
        var (appointment, client, therapist) = Scenario(AppointmentType.Online);
        appointment.Notes = null;
        appointment.Location = null;
        client.User.Email = null;
        var response = Map(appointment, client, therapist);
        Assert.Null(response.Notes);
        Assert.Null(response.Location);
        Assert.Null(response.PaymentId);
        Assert.Null(response.MeetingLink);
        Assert.Equal(string.Empty, response.ClientEmail);
    }

    [Theory]
    [InlineData("Past")]
    [InlineData("Duration")]
    [InlineData("MissingUtc")]
    [InlineData("Therapist")]
    [InlineData("Type")]
    [InlineData("Location")]
    public void Existing_creation_validator_rejects_invalid_requests(string fault)
    {
        var request = ValidRequest();
        switch (fault)
        {
            case "Past": request.StartUtc = DateTime.UtcNow.AddDays(-1); request.EndUtc = request.StartUtc.AddHours(1); break;
            case "Duration": request.EndUtc = request.StartUtc.AddMinutes(30); break;
            case "MissingUtc": request.StartUtc = DateTime.SpecifyKind(request.StartUtc, DateTimeKind.Unspecified); break;
            case "Therapist": request.TherapistId = 0; break;
            case "Type": request.Type = (AppointmentType)99; break;
            case "Location": request.Type = AppointmentType.InPerson; request.Location = null; break;
        }
        Assert.False(new CreateAppointmentDtoValidator().Validate(request).IsValid);
    }

    [Theory]
    [InlineData(AppointmentType.Online)]
    [InlineData(AppointmentType.InPerson)]
    public void Existing_creation_validator_accepts_valid_one_hour_utc_requests(AppointmentType type)
    {
        var request = ValidRequest();
        request.Type = type;
        request.Location = type == AppointmentType.InPerson ? "Synthetic office" : null;
        Assert.True(new CreateAppointmentDtoValidator().Validate(request).IsValid);
    }

    private static CreateAppointmentDto ValidRequest()
    {
        var start = DateTime.UtcNow.Date.AddDays(30).AddHours(9);
        return new() { TherapistId = 81, StartUtc = start, EndUtc = start.AddHours(1), Type = AppointmentType.Online };
    }

    private static AppointmentResponseDto Map(Appointment appointment, Client client, Therapist therapist) =>
        (AppointmentResponseDto)typeof(AppointmentService)
            .GetMethod("MapCreatedAppointment", BindingFlags.NonPublic | BindingFlags.Static)!
            .Invoke(null, new object[] { appointment, client, therapist })!;

    private static (Appointment Appointment, Client Client, Therapist Therapist) Scenario(AppointmentType type)
    {
        var client = new Client { Id = 71, UserId = 901,
            User = new() { Id = 901, FirstName = "Synthetic", LastName = "Client", Email = "client@example.invalid" } };
        var therapist = new Therapist { Id = 81, UserId = 902, HourlyRate = 50.25m,
            User = new() { Id = 902, FirstName = "Synthetic", LastName = "Therapist" } };
        var start = new DateTime(2030, 1, 1, 9, 0, 0, DateTimeKind.Utc);
        var appointment = new Appointment { Id = 91, ClientId = client.Id, TherapistId = therapist.Id,
            Price = 50.25m, StartUtc = start, EndUtc = start.AddHours(1), Status = AppointmentStatus.Pending,
            Type = type, Notes = "Synthetic notes", Location = type == AppointmentType.InPerson ? "Synthetic office" : null,
            MeetingLink = "https://example.invalid/private-session" };
        return (appointment, client, therapist);
    }
}
