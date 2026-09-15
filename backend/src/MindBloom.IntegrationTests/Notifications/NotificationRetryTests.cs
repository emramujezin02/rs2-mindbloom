using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.NotificationsWorker.Handlers.Notifications;
using MindBloom.NotificationsWorker.Services;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.Notifications;

public sealed class NotificationRetryTests
{
    [Fact]
    public async Task
        Handler_WhenInAppPersistenceFails_PropagatesFailureForWorkerRetry()
    {
        var databaseName =
            $"notification-retry-"
            + $"{Guid.NewGuid():N}";

        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    databaseName)
                .Options;

        await using var context =
            new ApplicationDbContext(
                options);

        var emailService =
            new RetryTestEmailService();

        var pushService =
            new RetryTestPushService();

        var notificationService =
            new WorkerNotificationService(
                context,
                emailService,
                pushService,
                new ApplicationMetrics(),
                NullLogger<
                    WorkerNotificationService>
                    .Instance);

        var handler =
            new NotificationRequestedEventHandler(
                context,
                notificationService,
                NullLogger<
                    NotificationRequestedEventHandler>
                    .Instance);

        /*
         * User ne postoji.
         *
         * In-app Notification ima UserId FK/business dependency
         * i worker obrada mora završiti greškom umjesto da
         * lažno označi event kao uspješan.
         *
         * IntegrationEventConsumer potom ovu običnu Exception
         * granu šalje kroz HandleTransientFailureAsync.
         */
        var integrationEvent =
            new NotificationRequestedEvent
            {
                UserId =
                    999999,

                Title =
                    "Retry test",

                Message =
                    "Notification worker retry test.",

                ActionType =
                    "None",

                SendEmail =
                    false,

                SendPush =
                    false
            };

        /*
         * Kod InMemory providera FK nije enforcement isti kao SQL,
         * zato direktno koristimo invalid notification payload
         * koji WorkerNotificationService mora odbiti.
         */
        integrationEvent =
            integrationEvent with
            {
                Title =
                    " "
            };

        await Assert.ThrowsAsync<
            ArgumentException>(
            () =>
                handler.HandleAsync(
                    integrationEvent,
                    CancellationToken.None));

        Assert.Equal(
            0,
            emailService.SendCount);

        Assert.Equal(
            0,
            pushService.SendCount);
    }

    [Fact]
    public async Task
        WorkerNotificationFlow_EmailFailure_DoesNotLoseInAppNotification()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"notification-channel-retry-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        await using var context =
            new ApplicationDbContext(
                options);

        var user =
            new ApplicationUser
            {
                UserName =
                    "notification-retry@test.local",

                Email =
                    "notification-retry@test.local",

                FirstName =
                    "Retry",

                LastName =
                    "Test",

                IsActive =
                    true,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.Users.Add(
            user);

        await context
            .SaveChangesAsync();

        var emailService =
            new RetryTestEmailService
            {
                Fail =
                    true
            };

        var pushService =
            new RetryTestPushService();

        var service =
            new WorkerNotificationService(
                context,
                emailService,
                pushService,
                new ApplicationMetrics(),
                NullLogger<
                    WorkerNotificationService>
                    .Instance);

        await service.NotifyAsync(
            user.Id,
            "Retry-safe notification",
            "In-app must survive email provider failure.",
            MindBloom.Domain.Enums
                .NotificationActionType.None,
            sendEmail:
                true,
            sendPush:
                true);

        Assert.Equal(
            1,
            await context.Notifications
                .CountAsync());

        Assert.Equal(
            1,
            emailService.SendCount);

        Assert.Equal(
            1,
            pushService.SendCount);
    }

    private sealed class
        RetryTestEmailService
        : IEmailService
    {
        public bool Fail
        {
            get;
            init;
        }

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

            if (Fail)
            {
                throw new InvalidOperationException(
                    "Simulated transient email failure.");
            }

            return Task.CompletedTask;
        }
    }

    private sealed class
        RetryTestPushService
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