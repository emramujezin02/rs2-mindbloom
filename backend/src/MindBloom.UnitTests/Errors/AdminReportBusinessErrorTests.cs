using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.AdminReports.DTOs;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Errors;

public sealed class AdminReportBusinessErrorTests
{
    [Fact]
    public async Task MissingAdministrator_RemainsExplicitBusinessError()
    {
        await using var context = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase($"report-business-error-{Guid.NewGuid():N}").Options);

        var error = await Assert.ThrowsAsync<BusinessException>(() => new AdminReportService(context)
            .GetAppointmentRevenueReportAsync(1, new AppointmentRevenueReportQueryDto
            {
                FromUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                ToUtc = new DateTime(2026, 1, 2, 0, 0, 0, DateTimeKind.Utc)
            }));

        Assert.Equal("Administrator was not found.", error.Message);
    }
}
