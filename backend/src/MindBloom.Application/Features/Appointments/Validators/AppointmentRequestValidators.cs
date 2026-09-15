using FluentValidation;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Appointments.Validators;

public sealed class CreateAppointmentDtoValidator
    : AbstractValidator<CreateAppointmentDto>
{
    public CreateAppointmentDtoValidator()
    {
        RuleFor(x => x.TherapistId)
            .GreaterThan(0)
            .WithMessage(
                "Therapist identifier must be greater than zero.");

        RuleFor(x => x.StartUtc)
            .NotEmpty()
            .WithMessage(
                "Appointment start time is required.")
            .Must(startUtc =>
                startUtc > DateTime.UtcNow)
            .WithMessage(
                "Appointment cannot be booked in the past.");

        RuleFor(x => x.EndUtc)
            .NotEmpty()
            .WithMessage(
                "Appointment end time is required.")
            .GreaterThan(x =>
                x.StartUtc)
            .WithMessage(
                "Appointment end time must be after start time.");

        RuleFor(x => x)
            .Must(x =>
                x.EndUtc - x.StartUtc ==
                TimeSpan.FromHours(1))
            .WithName("duration")
            .WithMessage(
                "Appointment must last exactly one hour.");

        RuleFor(x => x.Type)
            .IsInEnum()
            .WithMessage(
                "Appointment type is not valid.");



        RuleFor(x => x.Location)
            .NotEmpty()
            .WithMessage(
                "Location is required for in-person appointments.")
            .MaximumLength(250)
            .WithMessage(
                "Location may contain at most 250 characters.")
            .When(x =>
                x.Type ==
                AppointmentType.InPerson);

        RuleFor(x => x.Location)
            .MaximumLength(250)
            .WithMessage(
                "Location may contain at most 250 characters.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.Location));

        RuleFor(x => x.Notes)
    .MaximumLength(2000)
    .WithMessage(
        "Appointment notes may contain at most 2000 characters.")
    .When(x =>
        !string.IsNullOrWhiteSpace(
            x.Notes));

        RuleFor(x => x.MeetingLink)
            .MaximumLength(2000)
            .WithMessage(
                "Meeting link may contain at most 2000 characters.")
            .Must(BeValidAbsoluteHttpUrl)
            .WithMessage(
                "Meeting link must be a valid HTTP or HTTPS URL.")
            .When(x =>
                !string.IsNullOrWhiteSpace(
                    x.MeetingLink));
    }

    private static bool BeValidAbsoluteHttpUrl(
        string? value)
    {
        return Uri.TryCreate(
                   value,
                   UriKind.Absolute,
                   out var uri)
               && (uri.Scheme ==
                   Uri.UriSchemeHttp ||
                   uri.Scheme ==
                   Uri.UriSchemeHttps);
    }
}

public sealed class UpdateAppointmentStatusDtoValidator
    : AbstractValidator<UpdateAppointmentStatusDto>
{
    public UpdateAppointmentStatusDtoValidator()
    {
        RuleFor(x => x.AppointmentId)
            .GreaterThan(0)
            .WithMessage(
                "Appointment identifier must be greater than zero.");

        RuleFor(x => x.Status)
            .IsInEnum()
            .WithMessage(
                "Appointment status is not valid.");

        RuleFor(x => x.Status)
            .Must(status =>
                status is
                    AppointmentStatus.Accepted or
                    AppointmentStatus.Rejected or
                    AppointmentStatus.Completed)
            .WithMessage(
                "Therapist may only accept, reject or complete an appointment.");
    }
}

public sealed class CancelAppointmentDtoValidator
    : AbstractValidator<CancelAppointmentDto>
{
    public CancelAppointmentDtoValidator()
    {
        RuleFor(x => x.Reason)
            .NotEmpty()
            .WithMessage(
                "Cancellation reason is required.")
            .MinimumLength(5)
            .WithMessage(
                "Cancellation reason must contain at least 5 characters.")
            .MaximumLength(500)
            .WithMessage(
                "Cancellation reason may contain at most 500 characters.");
    }
}

public sealed class CreateAppointmentNoteDtoValidator
    : AbstractValidator<CreateAppointmentNoteDto>
{
    public CreateAppointmentNoteDtoValidator()
    {
        RuleFor(x => x.AppointmentId)
            .GreaterThan(0)
            .WithMessage(
                "Appointment identifier must be greater than zero.");

        RuleFor(x => x.Notes)
            .NotEmpty()
            .WithMessage(
                "Appointment notes are required.")
            .MaximumLength(4000)
            .WithMessage(
                "Appointment notes may contain at most 4000 characters.");

        RuleFor(x => x.ClientMood)
            .NotEmpty()
            .WithMessage(
                "Client mood is required.")
            .MaximumLength(250)
            .WithMessage(
                "Client mood may contain at most 250 characters.");

        RuleFor(x => x.Recommendations)
            .NotEmpty()
            .WithMessage(
                "Recommendations are required.")
            .MaximumLength(4000)
            .WithMessage(
                "Recommendations may contain at most 4000 characters.");
    }
}

public sealed class UpdateMeetingLinkDtoValidator
    : AbstractValidator<UpdateMeetingLinkDto>
{
    public UpdateMeetingLinkDtoValidator()
    {
        RuleFor(x => x.MeetingLink)
            .NotEmpty()
            .WithMessage(
                "Meeting link is required.")
            .MaximumLength(2000)
            .WithMessage(
                "Meeting link may contain at most 2000 characters.")
            .Must(BeValidAbsoluteHttpUrl)
            .WithMessage(
                "Meeting link must be a valid HTTP or HTTPS URL.");
    }

    private static bool BeValidAbsoluteHttpUrl(
        string value)
    {
        return Uri.TryCreate(
                   value,
                   UriKind.Absolute,
                   out var uri)
               && (uri.Scheme ==
                   Uri.UriSchemeHttp ||
                   uri.Scheme ==
                   Uri.UriSchemeHttps);
    }
}