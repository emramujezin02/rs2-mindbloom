using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class AppointmentSystemAuditMigrationSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Migration_PreservesHistoricalAuditAndAllowsSystemActor(bool historicalData)
    {
        const string previous = "20261028113556_AddClientSpecializationPreferences";
        const string current = "20261029090907_AllowSystemAppointmentStatusAudits";
        using var scope = factory.Services.CreateScope();
        var original = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var connection = new SqlConnectionStringBuilder(original.Database.GetConnectionString());
        Assert.StartsWith("MindBloomE2E_", connection.InitialCatalog);
        connection.InitialCatalog = $"Task12Migration_{Guid.NewGuid():N}";
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer(connection.ConnectionString).Options);
        try
        {
            var migrator = db.GetService<IMigrator>();
            await migrator.MigrateAsync(previous);
            Appointment? appointment = null;
            AppointmentStatusAudit? historical = null;
            if (historicalData)
            {
                appointment = await Seed(db);
                historical = new AppointmentStatusAudit
                {
                    AppointmentId = appointment.Id, ChangedByUserId = appointment.Client.UserId,
                    PreviousStatus = AppointmentStatus.Pending, NewStatus = AppointmentStatus.Accepted,
                    Action = "HistoricalTest", Reason = "Preserve this record", ChangedAtUtc = DateTime.UtcNow
                };
                db.Add(historical);
                await db.SaveChangesAsync();
            }
            await migrator.MigrateAsync(current);
            Assert.Contains(current, await db.Database.GetAppliedMigrationsAsync());
            Assert.Equal(1, await db.Database.SqlQueryRaw<int>("""
                SELECT CONVERT(int, is_nullable) AS [Value] FROM sys.columns
                WHERE object_id = OBJECT_ID('AppointmentStatusAudits') AND name = 'ChangedByUserId'
                """).SingleAsync());
            if (historicalData)
            {
                db.ChangeTracker.Clear();
                var saved = await db.AppointmentStatusAudits.SingleAsync();
                Assert.Equal(historical!.Id, saved.Id);
                Assert.Equal(historical.ChangedByUserId, saved.ChangedByUserId);
                Assert.Equal("Preserve this record", saved.Reason);
                Assert.Equal(2, await db.Users.CountAsync());
                Assert.Equal(1, await db.Clients.CountAsync());
                Assert.Equal(1, await db.Therapists.CountAsync());
                Assert.Equal(appointment!.Id, (await db.Appointments.SingleAsync()).Id);
            }
            else appointment = await Seed(db);

            db.Add(new AppointmentStatusAudit { AppointmentId = appointment!.Id, ChangedByUserId = null,
                PreviousStatus = AppointmentStatus.Accepted, NewStatus = AppointmentStatus.Completed,
                Action = "AutomaticCompletion", Reason = "System operation", ChangedAtUtc = DateTime.UtcNow });
            await db.SaveChangesAsync();
            Assert.Single(await db.AppointmentStatusAudits.Where(x => x.ChangedByUserId == null).ToListAsync());
            // A downgrade must fail safely instead of inventing user 0 or deleting system history.
            await Assert.ThrowsAsync<SqlException>(() => migrator.MigrateAsync(previous));
            Assert.Contains(current, await db.Database.GetAppliedMigrationsAsync());
            Assert.Equal(historicalData ? 2 : 1, await db.AppointmentStatusAudits.CountAsync());
        }
        finally
        {
            Assert.StartsWith("Task12Migration_", db.Database.GetDbConnection().Database);
            await db.Database.EnsureDeletedAsync();
        }
    }

    private static async Task<Appointment> Seed(ApplicationDbContext db)
    {
        ApplicationUser User() => new() { UserName = Guid.NewGuid().ToString(), FirstName = "Test", LastName = "Actor" };
        var appointment = new Appointment { Client = new Client { User = User() },
            Therapist = new Therapist { User = User(), Biography = "Test", Specialization = "Test" },
            Status = AppointmentStatus.Accepted, StartUtc = DateTime.UtcNow, EndUtc = DateTime.UtcNow.AddHours(1) };
        db.Add(appointment);
        await db.SaveChangesAsync();
        return appointment;
    }
}
