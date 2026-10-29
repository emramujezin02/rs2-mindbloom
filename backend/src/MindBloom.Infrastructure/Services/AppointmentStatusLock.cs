using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

// Separate from booking locks: serializes status writers across API instances.
internal sealed class AppointmentStatusLock(ApplicationDbContext context, string resource) : IAsyncDisposable
{
    public static async Task<IAsyncDisposable> AcquireAsync(ApplicationDbContext context, int appointmentId)
    {
        var resource = $"MindBloom.AppointmentStatus.{appointmentId}";
        var lease = new AppointmentStatusLock(context, resource);
        if (!context.Database.IsSqlServer()) return lease;

        await context.Database.OpenConnectionAsync();
        try
        {
            using var command = context.Database.GetDbConnection().CreateCommand();
            command.Transaction = context.Database.CurrentTransaction?.GetDbTransaction();
            command.CommandText = """
                DECLARE @result int;
                EXEC @result = sp_getapplock @Resource = @resource,
                    @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 10000;
                SELECT @result;
                """;
            var parameter = command.CreateParameter();
            parameter.ParameterName = "@resource";
            parameter.Value = resource;
            command.Parameters.Add(parameter);
            if (Convert.ToInt32(await command.ExecuteScalarAsync()) < 0)
                throw new BusinessException("Appointment status is being updated. Please try again.");
            return lease;
        }
        catch
        {
            await context.Database.CloseConnectionAsync();
            throw;
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (!context.Database.IsSqlServer()) return;
        try
        {
            if (context.Database.GetDbConnection().State == ConnectionState.Open)
                await context.Database.ExecuteSqlInterpolatedAsync(
                    $"EXEC sp_releaseapplock @Resource={resource}, @LockOwner='Session'");
        }
        finally
        {
            await context.Database.CloseConnectionAsync();
        }
    }
}
