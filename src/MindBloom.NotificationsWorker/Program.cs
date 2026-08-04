using DotNetEnv;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Infrastructure.Services;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Workers;

Env.TraversePath().Load();

var builder =
    Host.CreateApplicationBuilder(args);

builder.Configuration
    .AddEnvironmentVariables();

builder.Services
    .AddStandardRabbitMqConfiguration(
        builder.Configuration);

builder.Services.AddSingleton<
    IEmailService,
    EmailService>();

builder.Services.AddSingleton<
    EmailMessageBodyBuilder>();

builder.Services.AddHostedService<
    EmailNotificationConsumer>();

var host =
    builder.Build();

await host.RunAsync();