using MindBloom.Application.Features.Favorites.DTOs;

namespace MindBloom.Application.Features.Favorites.Interfaces;

public interface IFavoriteService
{
    Task AddAsync(
        int clientUserId,
        AddFavoriteDto request);

    Task RemoveAsync(
        int clientUserId,
        int therapistId);

    Task<List<FavoriteResponseDto>>
        GetMyFavoritesAsync(int clientUserId);
}
