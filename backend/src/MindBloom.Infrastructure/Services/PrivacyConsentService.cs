using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Privacy.DTOs;
using MindBloom.Application.Features.Privacy.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Services;

public sealed class PrivacyConsentService
    : IPrivacyConsentService
{
    private readonly ApplicationDbContext
        _context;

    public PrivacyConsentService(
        ApplicationDbContext context)
    {
        _context =
            context;
    }

    public async Task<List<UserConsentDto>>
        GetMyConsentsAsync(
            int userId)
    {
        return await _context.UserConsents
            .AsNoTracking()
            .Where(x =>
                x.UserId == userId &&
                !x.IsDeleted)
            .OrderByDescending(x =>
                x.AcceptedAtUtc)
            .Select(x =>
                new UserConsentDto
                {
                    ConsentType =
                        x.ConsentType
                            .ToString(),

                    DocumentVersion =
                        x.DocumentVersion,

                    IsAccepted =
                        x.IsAccepted,

                    AcceptedAtUtc =
                        x.AcceptedAtUtc
                })
            .ToListAsync();
    }

    public CurrentConsentVersionsDto
        GetCurrentVersions()
    {
        return new CurrentConsentVersionsDto
        {
            PrivacyPolicyVersion =
                ConsentDocumentConstants
                    .PrivacyPolicyVersion,

            TermsOfServiceVersion =
                ConsentDocumentConstants
                    .TermsOfServiceVersion,

            SensitiveDataProcessingVersion =
                ConsentDocumentConstants
                    .SensitiveDataProcessingVersion,

            SensitiveDataUsageExplanation =
                ConsentDocumentConstants
                    .SensitiveDataUsageExplanation
        };
    }
}