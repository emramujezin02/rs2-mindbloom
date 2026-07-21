using Microsoft.AspNetCore.Http;

namespace MindBloom.Application.Features.Therapists.DTOs;

public sealed class UploadTherapistProfileImageDto
{
    public IFormFile File { get; set; } = null!;
}