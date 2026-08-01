using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Workshops.DTOs;
using Microsoft.AspNetCore.Http;

namespace MindBloom.Application.Features.Workshops.Interfaces;

public interface IWorkshopService
{
    Task<PagedResponse<WorkshopResponseDto>>
        GetPublicAsync(
            WorkshopQueryDto query,
            int? clientUserId);

    Task<WorkshopResponseDto>
        GetByIdAsync(
            int workshopId,
            int? clientUserId);

    Task<PagedResponse<WorkshopResponseDto>>
        GetManageListAsync(
            int userId,
            bool isAdmin,
            WorkshopQueryDto query);

    Task<WorkshopResponseDto>
        CreateAsync(
            int userId,
            bool isAdmin,
            CreateWorkshopDto request);

    Task<WorkshopResponseDto>
        UpdateAsync(
            int userId,
            bool isAdmin,
            int workshopId,
            UpdateWorkshopDto request);

    Task<WorkshopResponseDto>
        UpdateStatusAsync(
            int userId,
            bool isAdmin,
            int workshopId,
            UpdateWorkshopStatusDto request);

    Task DeleteAsync(
        int userId,
        bool isAdmin,
        int workshopId);

    Task RegisterAsync(
        int clientUserId,
        int workshopId);

    Task CancelRegistrationAsync(
        int clientUserId,
        int workshopId);

    Task<PagedResponse<WorkshopResponseDto>>
        GetMyRegistrationsAsync(
            int clientUserId,
            int pageNumber,
            int pageSize);

    Task<PagedResponse<WorkshopRegistrationResponseDto>>
        GetRegistrationsAsync(
            int userId,
            bool isAdmin,
            int workshopId,
            int pageNumber,
            int pageSize);

    Task<WorkshopImageUploadDto>
    UploadImageAsync(
        IFormFile file);
}