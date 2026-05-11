namespace MindBloom.Application
.Features.Favorites.DTOs;
public class FavoriteResponseDto
{
    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;
}