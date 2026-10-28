using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Therapists;

public sealed class TherapistDocumentAccessApiTests
{
    [Theory]
    [InlineData(null, HttpStatusCode.Unauthorized)]
    [InlineData(RoleConstants.Client, HttpStatusCode.Forbidden)]
    [InlineData(RoleConstants.Admin, HttpStatusCode.Forbidden)]
    public async Task MyDocuments_RequiresTherapistRole(string? role, HttpStatusCode expected)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        if (role != null) await factory.SeedActiveUserAsync(801, role, "access@test.local", "TestingPassword123!");
        using var client = role == null ? factory.CreateClient() : factory.CreateAuthenticatedClient(801, role);
        Assert.Equal(expected, (await client.GetAsync("/api/Therapists/documents/me")).StatusCode);
    }

    [Fact]
    public async Task MyDocuments_IgnoresClientSuppliedTherapistIdAndOmitsPrivatePath()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        await factory.SeedActiveUserAsync(802, RoleConstants.Therapist, "first@test.local", "TestingPassword123!");
        await factory.SeedActiveUserAsync(803, RoleConstants.Therapist, "second@test.local", "TestingPassword123!");
        int secondId;
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var first = new Therapist { UserId = 802, VerificationStatus = TherapistVerificationStatus.Pending, Biography = "Test", Specialization = "Test" };
            var second = new Therapist { UserId = 803, VerificationStatus = TherapistVerificationStatus.Pending, Biography = "Test", Specialization = "Test" };
            context.Therapists.AddRange(first, second);
            await context.SaveChangesAsync();
            secondId = second.Id;
            context.TherapistDocuments.AddRange(
                new TherapistDocument { TherapistId = first.Id, FileName = "first.pdf", ContentType = "application/pdf", FilePath = "private-first" },
                new TherapistDocument { TherapistId = second.Id, FileName = "second.pdf", ContentType = "application/pdf", FilePath = "private-second" });
            await context.SaveChangesAsync();
        }
        using var client = factory.CreateAuthenticatedClient(802, RoleConstants.Therapist);
        var page = await client.GetFromJsonAsync<PagedResponse<TherapistDocumentResponseDto>>($"/api/Therapists/documents/me?therapistId={secondId}");
        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal("first.pdf", item.FileName);
        Assert.Empty(item.FilePath);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/Therapists/{secondId}/documents")).StatusCode);
    }
}
