using MindBloom.API.Messaging.RabbitMq;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Infrastructure.Services;

namespace MindBloom.API.Messaging.DependencyInjection;

public static class MessagingDependencyInjection
{
    public static IServiceCollection
        AddNotificationMessaging(
            this IServiceCollection services,
            IConfiguration configuration)
    {
        services
            .AddStandardRabbitMqConfiguration(
                configuration);

        services.AddSingleton<
            RabbitMqConnectionManager>();

        services.AddSingleton<
            IIntegrationEventPublisher,
            RabbitMqIntegrationEventPublisher>();

        services.AddScoped<
    IBusinessNotificationService,
    BusinessNotificationService>();

        services.AddSingleton<
            INotificationPublisher,
            RabbitMqNotificationPublisher>();

        return services;
    }
}