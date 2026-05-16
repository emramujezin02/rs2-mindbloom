using Microsoft.AspNetCore.Http;

namespace MindBloom.Application.Features.Therapists.DTOs;

public class UploadTherapistDocumentDto
{
    public IFormFile File { get; set; }
        = null!;
}