using Microsoft.AspNetCore.Identity;

namespace MindBloom.Domain.Entities;

public class ApplicationUser : IdentityUser<int>
{
    public string FirstName { get; set; } = null!;

    public string LastName { get; set; } = null!;

    public DateTime DateOfBirth { get; set; }

    public string? ProfileImageUrl { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAtUtc { get; set; }

    public bool IsEmailVerified { get; set; }

    public bool TwoFactorEnabledCustom { get; set; }

    public string? TwoFactorCode { get; set; }

    public DateTime? TwoFactorCodeExpiresAtUtc { get; set; }

    public ICollection<Appointment> ClientAppointments { get; set; }
        = new List<Appointment>();

    public ICollection<Appointment> TherapistAppointments { get; set; }
        = new List<Appointment>();

    public ICollection<Review> Reviews { get; set; }
        = new List<Review>();
}