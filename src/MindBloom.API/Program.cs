using DotNetEnv;
using MindBloom.API.Middlewares;
using Microsoft.AspNetCore.Identity;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.DependencyInjection;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Persistence.Context;


Env.Load("../../.env");

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen();

builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        policy =>
        {
            policy.AllowAnyHeader()
                .AllowAnyMethod()
                .AllowAnyOrigin();
        });
});

var app = builder.Build();

app.UseMiddleware<GlobalExceptionMiddleware>();

app.UseSwagger();

app.UseSwaggerUI();

app.UseCors("AllowAll");

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;

    var context =
        services.GetRequiredService<ApplicationDbContext>();

    var userManager =
        services.GetRequiredService<UserManager<ApplicationUser>>();

    var roleManager =
        services.GetRequiredService<RoleManager<IdentityRole<int>>>();

    await ApplicationDbSeeder.SeedAsync(
        context,
        userManager,
        roleManager);
}

app.Run();