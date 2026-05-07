using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Infrastructure.Persistence;

namespace MindBloom.Infrastructure.Configurations;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString =
            $"Server={Environment.GetEnvironmentVariable("DB_SERVER")};" +
            $"Database={Environment.GetEnvironmentVariable("DB_NAME")};" +
            $"User Id={Environment.GetEnvironmentVariable("DB_USER")};" +
            $"Password={Environment.GetEnvironmentVariable("DB_PASSWORD")};" +
            $"TrustServerCertificate=True;";

        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlServer(connectionString));

        return services;
    }
}