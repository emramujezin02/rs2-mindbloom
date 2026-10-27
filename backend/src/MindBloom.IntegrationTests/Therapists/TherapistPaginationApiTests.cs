using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;

namespace MindBloom.IntegrationTests.Therapists;

public sealed class TherapistPaginationApiTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PublicEndpoints_DefaultsMaximumAndPageBoundaries(bool filter)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            context.Therapists.AddRange(Enumerable.Range(1, 61).Select(index => new Therapist
            {
                User = new ApplicationUser { FirstName = "Test", LastName = index.ToString(), IsActive = true },
                Biography = "Pagination", Specialization = "Psychotherapy", HourlyRate = index,
                VerificationStatus = TherapistVerificationStatus.Approved
            }));
            await context.SaveChangesAsync();
        }
        using var client = factory.CreateClient();
        async Task<PagedResponse<TherapistResponseDto>> ReadAsync(string query, TherapistFilterDto? body = null)
        {
            var response = filter
                ? await client.PostAsJsonAsync($"/api/Therapists/filter{query}", body ?? new TherapistFilterDto())
                : await client.GetAsync($"/api/Therapists{query}");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            Assert.Equal(JsonValueKind.Object, json.RootElement.ValueKind);
            foreach (var name in new[] { "items", "pageNumber", "pageSize", "totalCount", "totalPages", "hasPreviousPage", "hasNextPage" })
                Assert.True(json.RootElement.TryGetProperty(name, out _));
            return (await response.Content.ReadFromJsonAsync<PagedResponse<TherapistResponseDto>>())!;
        }

        var defaults = await ReadAsync("");
        Assert.Equal(1, defaults.PageNumber);
        Assert.Equal(10, defaults.PageSize);
        Assert.Equal(10, defaults.Items.Count);
        Assert.Equal(61, defaults.TotalCount);
        Assert.Equal(7, defaults.TotalPages);
        var second = await ReadAsync("?Page=2&PageSize=10");
        Assert.Equal(10, second.Items.Count);
        Assert.Empty(defaults.Items.Select(x => x.Id).Intersect(second.Items.Select(x => x.Id)));
        var maximum = await ReadAsync("?Page=1&PageSize=2147483647");
        Assert.Equal(50, maximum.PageSize);
        Assert.Equal(50, maximum.Items.Count);
        var last = await ReadAsync("?Page=2&PageSize=50");
        Assert.Equal(11, last.Items.Count);
        Assert.False(last.HasNextPage);
        Assert.Empty((await ReadAsync("?Page=3&PageSize=50")).Items);
        Assert.Empty((await ReadAsync("?Page=2147483647&PageSize=50")).Items);
        foreach (var query in new[] { "?Page=0&PageSize=0", "?Page=-1&PageSize=-1" })
        {
            var normalized = await ReadAsync(query);
            Assert.Equal(1, normalized.PageNumber);
            Assert.Equal(10, normalized.PageSize);
        }
        if (filter)
        {
            var selected = await ReadAsync("?Page=2&PageSize=3", new TherapistFilterDto
            {
                Specialization = "therapy", MinPrice = 10, MaxPrice = 20
            });
            Assert.Equal(11, selected.TotalCount);
            Assert.Equal(new decimal[] { 13, 14, 15 }, selected.Items.Select(x => x.HourlyRate));
        }
        var invalid = filter
            ? await client.PostAsJsonAsync("/api/Therapists/filter?Page=invalid", new TherapistFilterDto())
            : await client.GetAsync("/api/Therapists?Page=invalid");
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task EmptyDatabase_ReturnsEmptyPagedObject(bool filter)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using var client = factory.CreateClient();
        var response = filter
            ? await client.PostAsJsonAsync("/api/Therapists/filter", new TherapistFilterDto())
            : await client.GetAsync("/api/Therapists");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<PagedResponse<TherapistResponseDto>>();
        Assert.NotNull(page);
        Assert.Empty(page.Items);
        Assert.Equal(0, page.TotalCount);
        Assert.Equal(0, page.TotalPages);
    }
}
