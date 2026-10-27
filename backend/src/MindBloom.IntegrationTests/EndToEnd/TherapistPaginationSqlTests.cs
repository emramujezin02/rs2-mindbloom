using System.Collections.Concurrent;
using System.Data.Common;
using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class TherapistPaginationSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Fact]
    public async Task PublicEndpoints_ExecutePagingInSqlBeforeMaterializingTherapists()
    {
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            context.Therapists.AddRange(Enumerable.Range(1, 7).Select(index => new Therapist
            {
                User = new ApplicationUser
                {
                    UserName = $"pagination-{Guid.NewGuid():N}@test.local", FirstName = "SQL", LastName = index.ToString(), IsActive = true
                },
                Biography = "SQL pagination test", Specialization = "Psychotherapy", HourlyRate = index,
                VerificationStatus = TherapistVerificationStatus.Approved, Country = "Test", City = "Test",
                Address = "Test", Education = "Test"
            }));
            await context.SaveChangesAsync();
        }
        var observer = new PagingCommandObserver();
        using var application = factory.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
            services.AddDbContext<ApplicationDbContext>(options => options.AddInterceptors(observer))));
        using var client = application.CreateClient();
        foreach (var filter in new[] { false, true })
        {
            observer.Commands.Clear();
            var response = filter
                ? await client.PostAsJsonAsync("/api/Therapists/filter?Page=2&PageSize=2",
                    new TherapistFilterDto { MinPrice = 2, MaxPrice = 6, SortByRating = true })
                : await client.GetAsync("/api/Therapists?Page=2&PageSize=2");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var page = await response.Content.ReadFromJsonAsync<PagedResponse<TherapistResponseDto>>();
            Assert.NotNull(page);
            Assert.Equal(2, page.Items.Count);
            Assert.Equal(filter ? 5 : 7, page.TotalCount);
            var therapistQueries = observer.Commands.Where(sql => sql.Contains("[Therapists]", StringComparison.Ordinal)).ToList();
            Assert.Contains(therapistQueries, sql => sql.Contains("COUNT(", StringComparison.Ordinal));
            var itemQueries = therapistQueries.Where(sql => !sql.Contains("COUNT(", StringComparison.Ordinal)
                || sql.Contains("OFFSET", StringComparison.Ordinal)).ToList();
            Assert.NotEmpty(itemQueries);
            Assert.All(itemQueries, sql =>
            {
                Assert.Contains("ORDER BY", sql);
                Assert.Contains("OFFSET", sql);
                Assert.Contains("FETCH NEXT", sql);
            });
        }
    }

    private sealed class PagingCommandObserver : DbCommandInterceptor
    {
        public ConcurrentQueue<string> Commands { get; } = new();

        public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
            DbCommand command, CommandEventData eventData, InterceptionResult<DbDataReader> result,
            CancellationToken cancellationToken = default)
        {
            Commands.Enqueue(command.CommandText);
            return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
        }
    }
}
