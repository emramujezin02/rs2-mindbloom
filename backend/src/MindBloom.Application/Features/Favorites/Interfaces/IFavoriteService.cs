using MindBloom.Application.Features.Favorites.DTOs;

using MindBloom.Application.Common.Models;

namespace MindBloom.Application.Features.Favorites.Interfaces;

public interface IFavoriteService
{
    Task AddAsync(
        int clientUserId,
        AddFavoriteDto request);

    Task RemoveAsync(
        int clientUserId,
        int therapistId);

    Task<PagedResponse<FavoriteResponseDto>>
        GetMyFavoritesAsync(
            int clientUserId,
            int pageNumber,
            int pageSize,
            int? therapistId);
}
