using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Handlers;
using MindBloom.NotificationsWorker.Handlers.Notifications;
using MindBloom.NotificationsWorker.Services;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.Notifications;

public sealed class NotificationWorkerTests
{
    [Fact]
    public async Task
        Dispatcher_NotificationRequestedEvent_InvokesNotificationHandler()
    {
        var databaseName =
            $"notification-worker-"
            + $"{Guid.NewGuid():N}";

        var services =
            CreateServices(
                databaseName);

        await using var provider =
            services
                .BuildServiceProvider();

        var userId =
            await SeedUserAsync(
                provider,
                "worker-notification@test.local");

        var dispatcher =
            new IntegrationEventDispatcher(
                provider
                    .GetRequiredService<
                        IServiceScopeFactory>(),
                NullLogger<
                    IntegrationEventDispatcher>
                    .Instance);

        var integrationEvent =
            new NotificationRequestedEvent
            {
                UserId =
                    userId,

                Title =
                    "Appointment reminder",

                Message =
                    "Your appointment starts soon.",

                ActionType =
                    "Appointment",

                AppointmentId =
                    456,

                ResourceId =
                    456,

                SendEmail =
                    true,

                SendPush =
                    true
            };

        await dispatcher.DispatchAsync(
            integrationEvent,
            CancellationToken.None);

        using var scope =
            provider.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var notification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync();

        Assert.Equal(
            userId,
            notification.UserId);

        Assert.Equal(
            "Appointment reminder",
            notification.Title);

        Assert.Equal(
            "Your appointment starts soon.",
            notification.Message);

        Assert.Equal(
            456,
            notification.AppointmentId);

        var email =
            scope.ServiceProvider
                .GetRequiredService<
                    TestWorkerEmailService>();

        var push =
            scope.ServiceProvider
                .GetRequiredService<
                    TestWorkerPushService>();

        Assert.Equal(
            1,
            email.SendCount);

        Assert.Equal(
            1,
            push.SendCount);
    }

    [Fact]
    public async Task
        NotificationHandler_DuplicateNotificationId_DoesNotCreateAnotherNotification()
    {
        var databaseName =
            $"notification-worker-duplicate-"
            + $"{Guid.NewGuid():N}";

        var services =
            CreateServices(
                databaseName);

        await using var provider =
            services
                .BuildServiceProvider();

        var userId =
            await SeedUserAsync(
                provider,
                "worker-duplicate@test.local");

        int existingNotificationId;

        using (
            var seedScope =
                provider.CreateScope())
        {
            var context =
                seedScope.ServiceProvider
                    .GetRequiredService<
                        ApplicationDbContext>();

            var notification =
                new Notification
                {
                    UserId =
                        userId,

                    Title =
                        "Existing notification",

                    Message =
                        "Already created.",

                    IsRead =
                        false,

                    SentAtUtc =
                        DateTime.UtcNow,

                    CreatedAtUtc =
                        DateTime.UtcNow
                };

            context.Notifications.Add(
                notification);

            await context
                .SaveChangesAsync();

            existingNotificationId =
                notification.Id;
        }

        using (
            var handlerScope =
                provider.CreateScope())
        {
            var handler =
                handlerScope
                    .ServiceProvider
                    .GetRequiredService<
                        IIntegrationEventHandler<
                            NotificationRequestedEvent>>();

            await handler.HandleAsync(
                new NotificationRequestedEvent
                {
                    UserId =
                        userId,

                    Title =
                        "Duplicate notification",

                    Message =
                        "This must not create another record.",

                    ActionType =
                        "None",

                    NotificationId =
                        existingNotificationId,

                    SendEmail =
                        true,

                    SendPush =
                        true
                },
                CancellationToken.None);
        }

        using var verificationScope =
            provider.CreateScope();

        var verificationContext =
            verificationScope
                .ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        Assert.Equal(
            1,
            await verificationContext
                .Notifications
                .CountAsync());

        var email =
            verificationScope
                .ServiceProvider
                .GetRequiredService<
                    TestWorkerEmailService>();

        var push =
            verificationScope
                .ServiceProvider
                .GetRequiredService<
                    TestWorkerPushService>();

        Assert.Equal(
            0,
            email.SendCount);

        Assert.Equal(
            0,
            push.SendCount);
    }

    private static ServiceCollection
        CreateServices(
            string databaseName)
    {
        var services =
            new ServiceCollection();

        services.AddDbContext<
            ApplicationDbContext>(
            options =>
                options.UseInMemoryDatabase(
                    databaseName));

        services.AddSingleton<
            ApplicationMetrics>();

        services.AddSingleton<
            TestWorkerEmailService>();

        services.AddSingleton<
            TestWorkerPushService>();

        services.AddSingleton<
            IEmailService>(
            provider =>
                provider
                    .GetRequiredService<
                        TestWorkerEmailService>());

        services.AddSingleton<
            IPushNotificationService>(
            provider =>
                provider
                    .GetRequiredService<
                        TestWorkerPushService>());

        services.AddScoped<
            WorkerNotificationService>();

        services.AddScoped<
            IIntegrationEventHandler<
                NotificationRequestedEvent>,
            NotificationRequestedEventHandler>();

        services.AddLogging();

        return services;
    }

    private static async Task<int>
        SeedUserAsync(
            ServiceProvider provider,
            string email)
    {
        using var scope =
            provider.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var user =
            new ApplicationUser
            {
                UserName =
                    email,

                NormalizedUserName =
                    email.ToUpperInvariant(),

                Email =
                    email,

                NormalizedEmail =
                    email.ToUpperInvariant(),

                FirstName =
                    "Worker",

                LastName =
                    "Test",

                EmailConfirmed =
                    true,

                IsActive =
                    true,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.Users.Add(
            user);

        await context
            .SaveChangesAsync();

        return user.Id;
    }

    private sealed class
        TestWorkerEmailService
        : IEmailService
    {
        public int SendCount
        {
            get;
            private set;
        }

        public Task SendAsync(
            string to,
            string subject,
            string body)
        {
            SendCount++;

            return Task.CompletedTask;
        }
    }

    private sealed class
        TestWorkerPushService
        : IPushNotificationService
    {
        public int SendCount
        {
            get;
            private set;
        }

        public Task SendToUserAsync(
            int userId,
            string title,
            string message,
            IReadOnlyDictionary<
                string,
                string>? data = null,
            CancellationToken cancellationToken =
                default)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            SendCount++;

            return Task.CompletedTask;
        }
    }
}