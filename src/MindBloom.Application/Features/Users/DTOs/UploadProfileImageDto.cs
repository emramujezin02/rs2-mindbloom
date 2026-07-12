using Microsoft.AspNetCore.Http;

namespace MindBloom.Application.Features.Users.DTOs;

public class UploadProfileImageDto
{
    public IFormFile File { get; set; } = null!;
}