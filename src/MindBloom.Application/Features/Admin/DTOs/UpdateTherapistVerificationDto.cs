using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Admin.DTOs;

public class UpdateTherapistVerificationDto
{
    public TherapistVerificationStatus
        Status
    {
        get;
        set;
    }

    public string? Notes
    {
        get;
        set;
    }
}