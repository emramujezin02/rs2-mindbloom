using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using MindBloom.Infrastructure.Services;
using MindBloom.Application.Features.Reviews.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Application.Features.Favorites.Interfaces;

namespace MindBloom.Infrastructure.DependencyInjection;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString =
            Environment.GetEnvironmentVariable("DB_CONNECTION");

        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlServer(connectionString));


        services.AddSignalR();

        services.AddIdentity<ApplicationUser, IdentityRole<int>>(options =>
        {
            options.Password.RequireDigit = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireUppercase = true;
            options.Password.RequireNonAlphanumeric = false;
            options.Password.RequiredLength = 6;
        })
        .AddEntityFrameworkStores<ApplicationDbContext>()
        .AddDefaultTokenProviders();

        var jwtSettings = new JwtSettings
        {
            SecretKey = Environment.GetEnvironmentVariable("JWT_SECRET")!,
            Issuer = Environment.GetEnvironmentVariable("JWT_ISSUER")!,
            Audience = Environment.GetEnvironmentVariable("JWT_AUDIENCE")!,
            ExpirationInMinutes = int.Parse(
                Environment.GetEnvironmentVariable("JWT_EXPIRATION_MINUTES")!)
        };

        services.Configure<JwtSettings>(options =>
        {
            options.SecretKey = jwtSettings.SecretKey;
            options.Issuer = jwtSettings.Issuer;
            options.Audience = jwtSettings.Audience;
            options.ExpirationInMinutes =
                jwtSettings.ExpirationInMinutes;
        });

        var key = Encoding.UTF8.GetBytes(jwtSettings.SecretKey);

        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme =
                JwtBearerDefaults.AuthenticationScheme;

            options.DefaultChallengeScheme =
                JwtBearerDefaults.AuthenticationScheme;
        })
       .AddJwtBearer(options =>
       {
           options.TokenValidationParameters =
               new TokenValidationParameters
               {
                   ValidateIssuer = true,
                   ValidateAudience = true,
                   ValidateLifetime = true,
                   ValidateIssuerSigningKey = true,

                   ValidIssuer = jwtSettings.Issuer,
                   ValidAudience = jwtSettings.Audience,

                   IssuerSigningKey =
                       new SymmetricSecurityKey(key)
               };

           options.Events = new JwtBearerEvents
           {
               OnMessageReceived = context =>
               {
                   var accessToken =
                       context.Request.Query["access_token"];

                   var path =
                       context.HttpContext.Request.Path;

                   if (!string.IsNullOrEmpty(accessToken)
                       && path.StartsWithSegments(
                           "/hubs/notifications"))
                   {
                       context.Token = accessToken;
                   }

                   return Task.CompletedTask;
               }
           };
       });

        services.AddScoped<IJwtTokenService, JwtTokenService>();

        services.AddScoped<IAuthService, AuthService>();

        services.AddScoped<ITherapistService, TherapistService>();

        services.AddScoped<IAppointmentService, AppointmentService>();

        services.AddScoped<IReviewService, ReviewService>();

        services.AddScoped<IPaymentService, PaymentService>();

        services.AddScoped<INotificationService,NotificationService>();

        services.AddScoped<INotificationSender,SignalRNotificationSender>();

        services.AddScoped<IFavoriteService, FavoriteService>();

        services.AddScoped<IEmailService, EmailService>();

        return services;
    }
}