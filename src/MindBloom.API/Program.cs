using DotNetEnv;
using Microsoft.AspNetCore.Identity;
using Microsoft.OpenApi.Models;
using MindBloom.API.Middlewares;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.DependencyInjection;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Realtime;
using DotNetEnv;
using MindBloom.API.Messaging.DependencyInjection;


Env.Load("../../.env");

Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddEnvironmentVariables();

builder.Services.AddControllers();

builder.Services.AddNotificationMessaging(builder.Configuration);

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddCors(options =>
{
    options.AddPolicy(
        "AllowAll",
        policy =>
        {
            policy
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowAnyOrigin();
        });
});

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc(
        "v1",
        new OpenApiInfo
        {
            Title =
                "MindBloom API",

            Version =
                "v1"
        });

    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Name =
                "Authorization",

            Type =
                SecuritySchemeType.Http,

            Scheme =
                "bearer",

            BearerFormat =
                "JWT",

            In =
                ParameterLocation.Header,

            Description =
                "Enter JWT access token."
        });

    options.AddSecurityRequirement(
        new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference =
                        new OpenApiReference
                        {
                            Type =
                                ReferenceType
                                    .SecurityScheme,

                            Id =
                                "Bearer"
                        }
                },
                Array.Empty<string>()
            }
        });
});

var app =
    builder.Build();

app.UseMiddleware<
    GlobalExceptionMiddleware>();

app.UseSwagger();

app.UseSwaggerUI();

app.UseCors("AllowAll");

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.MapHub<NotificationHub>("/hubs/notifications").RequireAuthorization();

app.MapHub<ChatHub>("/hubs/chat");

using (var scope =
       app.Services.CreateScope())
{
    var services =
        scope.ServiceProvider;

    var context =
        services.GetRequiredService<
            ApplicationDbContext>();

    var userManager =
        services.GetRequiredService<
            UserManager<ApplicationUser>>();

    var roleManager =
        services.GetRequiredService<
            RoleManager<
                IdentityRole<int>>>();

    await ApplicationDbSeeder
        .SeedAsync(
            context,
            userManager,
            roleManager);
}

app.Run();