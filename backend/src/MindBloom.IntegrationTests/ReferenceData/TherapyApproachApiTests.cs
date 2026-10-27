using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;

namespace MindBloom.IntegrationTests.ReferenceData;

public sealed class TherapyApproachApiTests
{
    [Theory]
    [InlineData("/api/TherapyApproaches/public")]
    [InlineData("/api/reference-data/therapy-approaches/active")]
    public async Task PublicTherapyApproaches_ReturnsActiveDtosWithoutIconUrl(string route)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            context.TherapyApproaches.AddRange(
                new TherapyApproach { Name = "Zulu", Description = "Zulu description" },
                new TherapyApproach { Name = "Alpha", Description = null },
                new TherapyApproach { Name = "Inactive", IsActive = false },
                new TherapyApproach { Name = "Deleted", IsActive = true, IsDeleted = true });
            await context.SaveChangesAsync();
        }
        using var client = factory.CreateClient();

        var response = await client.GetAsync(route);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var result = await response.Content.ReadFromJsonAsync<List<TherapyApproachResponseDto>>();
        Assert.NotNull(result);
        Assert.Equal(new[] { "Alpha", "Zulu" }, result.Select(x => x.Name));
        Assert.All(result, approach =>
        {
            Assert.True(approach.Id > 0);
            Assert.True(approach.IsActive);
        });
        Assert.Null(result[0].Description);
        Assert.Equal("Zulu description", result[1].Description);

        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        foreach (var approach in json.RootElement.EnumerateArray())
        {
            Assert.False(approach.TryGetProperty("iconUrl", out _));
            Assert.True(approach.TryGetProperty("createdAtUtc", out _));
            Assert.True(approach.TryGetProperty("therapistCount", out _));
            Assert.True(approach.TryGetProperty("clientCount", out _));
        }
        var referenceResponse = await client.GetStringAsync("/api/reference-data/therapy-approaches/active");
        Assert.Equal(referenceResponse, await response.Content.ReadAsStringAsync());
    }

    [Theory]
    [InlineData("/api/TherapyApproaches/public")]
    [InlineData("/api/reference-data/therapy-approaches/active")]
    public async Task PublicTherapyApproaches_WhenNoApproachesExist_ReturnsEmptyArray(string route)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync(route);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("[]", await response.Content.ReadAsStringAsync());
    }
}
