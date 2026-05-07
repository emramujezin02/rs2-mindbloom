using Microsoft.AspNetCore.Identity;

namespace MindBloom.Domain.Entities;

public class ApplicationUser : IdentityUser<int>
{
    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string? ProfileImagePath { get; set; }

    public bool IsActive { get; set; } = true;

    public virtual Therapist? TherapistProfile { get; set; }

    public virtual Client? ClientProfile { get; set; }
}