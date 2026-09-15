using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.NotificationsWorker.Services;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.Notifications;

public sealed class WorkerNotificationServiceTests
{
    [Fact]
    public async Task
        CreateAsync_CreatesInAppNotification()
    {
        await using var context =
            CreateDbContext();

        var emailService =
            new TestEmailService();

        var pushService =
            new TestPushNotificationService();

        var service =
            CreateService(
                context,
                emailService,
                pushService);

        var user =
            await SeedUserAsync(
                context,
                "notification-inapp@test.local");

        await service.CreateAsync(
            user.Id,
            "Appointment updated",
            "Your appointment has been updated.",
            NotificationActionType.Appointment,
            appointmentId:
                123,
            resourceId:
                123);

        var notification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync();

        Assert.Equal(
            user.Id,
            notification.UserId);

        Assert.Equal(
            "Appointment updated",
            notification.Title);

        Assert.Equal(
            "Your appointment has been updated.",
            notification.Message);

        Assert.False(
            notification.IsRead);

        Assert.Equal(
            NotificationActionType.Appointment,
            notification.ActionType);

        Assert.Equal(
            123,
            notification.AppointmentId);

        Assert.Equal(
            123,
            notification.ResourceId);

        Assert.True(
            notification.SentAtUtc >
            DateTime.MinValue);

        /*
         * CreateAsync kreira samo in-app zapis.
         * Ne smije samostalno slati email/push.
         */
        Assert.Equal(
            0,
            emailService.SendCount);

        Assert.Equal(
            0,
            pushService.SendCount);
    }

    [Fact]
    public async Task
        NotifyAsync_SendsEmailAndPushAndCreatesInAppNotification()
    {
        await using var context =
            CreateDbContext();

        var emailService =
            new TestEmailService();

        var pushService =
            new TestPushNotificationService();

        var service =
            CreateService(
                context,
                emailService,
                pushService);

        var user =
            await SeedUserAsync(
                context,
                "notification-all@test.local");

        await service.NotifyAsync(
            user.Id,
            "Payment completed",
            "Your payment was completed successfully.",
            NotificationActionType.Payment,
            resourceId:
                7001,
            sendEmail:
                true,
            sendPush:
                true);

        /*
         * IN-APP
         */
        var notification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync();

        Assert.Equal(
            user.Id,
            notification.UserId);

        Assert.Equal(
            "Payment completed",
            notification.Title);

        Assert.Equal(
            NotificationActionType.Payment,
            notification.ActionType);

        Assert.Equal(
            7001,
            notification.ResourceId);

        /*
         * EMAIL
         */
        Assert.Equal(
            1,
            emailService.SendCount);

        var email =
            Assert.Single(
                emailService.SentEmails);

        Assert.Equal(
            user.Email,
            email.To);

        Assert.Equal(
            "Payment completed",
            email.Subject);

        Assert.Equal(
            "Your payment was completed successfully.",
            email.Body);

        /*
         * PUSH
         */
        Assert.Equal(
            1,
            pushService.SendCount);

        var push =
            Assert.Single(
                pushService.SentNotifications);

        Assert.Equal(
            user.Id,
            push.UserId);

        Assert.Equal(
            "Payment completed",
            push.Title);

        Assert.Equal(
            "Your payment was completed successfully.",
            push.Message);

        Assert.NotNull(
            push.Data);

        Assert.Equal(
            NotificationActionType.Payment
                .ToString(),
            push.Data![
                "actionType"]);

        Assert.Equal(
            "7001",
            push.Data[
                "resourceId"]);
    }

    [Fact]
    public async Task
        NotifyAsync_WhenEmailFails_PreservesInAppAndStillSendsPush()
    {
        await using var context =
            CreateDbContext();

        var emailService =
            new TestEmailService
            {
                ThrowOnSend =
                    true
            };

        var pushService =
            new TestPushNotificationService();

        var service =
            CreateService(
                context,
                emailService,
                pushService);

        var user =
            await SeedUserAsync(
                context,
                "notification-email-failure@test.local");

        /*
         * WorkerNotificationService namjerno ne propagira
         * običnu email grešku. In-app mora ostati sačuvan,
         * a push se i dalje pokušava poslati.
         */
        await service.NotifyAsync(
            user.Id,
            "Workshop reminder",
            "Your workshop starts soon.",
            NotificationActionType.Workshop,
            resourceId:
                8100,
            sendEmail:
                true,
            sendPush:
                true);

        var notification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync();

        Assert.Equal(
            "Workshop reminder",
            notification.Title);

        Assert.False(
            notification.IsRead);

        Assert.Equal(
            1,
            emailService.SendCount);

        Assert.Empty(
            emailService.SentEmails);

        Assert.Equal(
            1,
            pushService.SendCount);

        Assert.Single(
            pushService
                .SentNotifications);
    }

    [Fact]
    public async Task
        NotifyAsync_WhenPushFails_PreservesInAppAndEmail()
    {
        await using var context =
            CreateDbContext();

        var emailService =
            new TestEmailService();

        var pushService =
            new TestPushNotificationService
            {
                ThrowOnSend =
                    true
            };

        var service =
            CreateService(
                context,
                emailService,
                pushService);

        var user =
            await SeedUserAsync(
                context,
                "notification-push-failure@test.local");

        await service.NotifyAsync(
            user.Id,
            "Membership activated",
            "Your membership is now active.",
            NotificationActionType.Membership,
            resourceId:
                9100,
            sendEmail:
                true,
            sendPush:
                true);

        /*
         * In-app zapis mora postojati bez obzira
         * što je push provider pao.
         */
        var notification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync();

        Assert.Equal(
            user.Id,
            notification.UserId);

        Assert.Equal(
            "Membership activated",
            notification.Title);

        Assert.Equal(
            NotificationActionType.Membership,
            notification.ActionType);

        /*
         * Email je prije push dijela uspješno poslan.
         */
        Assert.Equal(
            1,
            emailService.SendCount);

        Assert.Single(
            emailService.SentEmails);

        /*
         * Push je pokušao slanje, ali je provider
         * simulirano bacio grešku.
         */
        Assert.Equal(
            1,
            pushService.SendCount);

        Assert.Empty(
            pushService
                .SentNotifications);
    }

    [Fact]
    public async Task
        NotifyAsync_WhenChannelsDisabled_CreatesOnlyInAppNotification()
    {
        await using var context =
            CreateDbContext();

        var emailService =
            new TestEmailService();

        var pushService =
            new TestPushNotificationService();

        var service =
            CreateService(
                context,
                emailService,
                pushService);

        var user =
            await SeedUserAsync(
                context,
                "notification-inapp-only@test.local");

        await service.NotifyAsync(
            user.Id,
            "Review updated",
            "Your review status has changed.",
            NotificationActionType.Review,
            resourceId:
                111,
            sendEmail:
                false,
            sendPush:
                false);

        Assert.Equal(
            1,
            await context.Notifications
                .CountAsync());

        Assert.Equal(
            0,
            emailService.SendCount);

        Assert.Equal(
            0,
            pushService.SendCount);
    }

    [Fact]
    public async Task
        SendEmailAsync_UsesUsersStoredEmailAddress()
    {
        await using var context =
            CreateDbContext();

        var emailService =
            new TestEmailService();

        var pushService =
            new TestPushNotificationService();

        var service =
            CreateService(
                context,
                emailService,
                pushService);

        var user =
            await SeedUserAsync(
                context,
                "notification-direct-email@test.local");

        await service.SendEmailAsync(
            user.Id,
            "MindBloom notification",
            "Notification body");

        Assert.Equal(
            1,
            emailService.SendCount);

        var email =
            Assert.Single(
                emailService.SentEmails);

        Assert.Equal(
            "notification-direct-email@test.local",
            email.To);

        Assert.Equal(
            "MindBloom notification",
            email.Subject);

        Assert.Equal(
            "Notification body",
            email.Body);
    }

    private static WorkerNotificationService
        CreateService(
            ApplicationDbContext context,
            IEmailService emailService,
            IPushNotificationService
                pushNotificationService)
    {
        return new WorkerNotificationService(
            context,
            emailService,
            pushNotificationService,
            new ApplicationMetrics(),
            NullLogger<
                WorkerNotificationService>
                .Instance);
    }

    private static ApplicationDbContext
        CreateDbContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"notification-tests-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static async Task<ApplicationUser>
        SeedUserAsync(
            ApplicationDbContext context,
            string email)
    {
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
                    "Notification",

                LastName =
                    "Tester",

                IsActive =
                    true,

                EmailConfirmed =
                    true,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.Users.Add(
            user);

        await context
            .SaveChangesAsync();

        return user;
    }

    private sealed class TestEmailService
        : IEmailService
    {
        private readonly List<SentEmail>
            _sentEmails =
                [];

        public int SendCount
        {
            get;
            private set;
        }

        public bool ThrowOnSend
        {
            get;
            init;
        }

        public IReadOnlyList<SentEmail>
            SentEmails =>
                _sentEmails;

        public Task SendAsync(
            string to,
            string subject,
            string body)
        {
            SendCount++;

            if (ThrowOnSend)
            {
                throw new InvalidOperationException(
                    "Simulated email provider failure.");
            }

            _sentEmails.Add(
                new SentEmail(
                    to,
                    subject,
                    body));

            return Task.CompletedTask;
        }

        public sealed record SentEmail(
            string To,
            string Subject,
            string Body);
    }

    private sealed class
        TestPushNotificationService
        : IPushNotificationService
    {
        private readonly List<
            SentPushNotification>
            _sentNotifications =
                [];

        public int SendCount
        {
            get;
            private set;
        }

        public bool ThrowOnSend
        {
            get;
            init;
        }

        public IReadOnlyList<
            SentPushNotification>
            SentNotifications =>
                _sentNotifications;

        public Task SendToUserAsync(
            int userId,
            string title,
            string message,
            IReadOnlyDictionary<
                string,
                string>? data = null,
            CancellationToken
                cancellationToken =
                    default)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            SendCount++;

            if (ThrowOnSend)
            {
                throw new InvalidOperationException(
                    "Simulated push provider failure.");
            }

            _sentNotifications.Add(
                new SentPushNotification(
                    userId,
                    title,
                    message,
                    data));

            return Task.CompletedTask;
        }

        public sealed record
            SentPushNotification(
                int UserId,
                string Title,
                string Message,
                IReadOnlyDictionary<
                    string,
                    string>? Data);
    }
}