using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Reviews;

public sealed class ReviewServiceTests
{
    [Fact]
    public async Task CreateAsync_WhenClientDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var notificationMock =
            CreateNotificationMock();

        var service =
            new ReviewService(
                context,
                notificationMock.Object);

        var request =
            new CreateReviewDto
            {
                AppointmentId = 1,
                Rating = 5,
                Comment = "Excellent session."
            };

        await Assert.ThrowsAsync<NotFoundException>(
            () =>
                service.CreateAsync(
                    999,
                    request));
    }

    [Fact]
    public async Task CreateAsync_WhenAppointmentDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var request =
            new CreateReviewDto
            {
                AppointmentId = 999,
                Rating = 5,
                Comment = "Excellent session."
            };

        await Assert.ThrowsAsync<NotFoundException>(
            () =>
                service.CreateAsync(
                    10,
                    request));
    }

    [Fact]
    public async Task CreateAsync_WhenAppointmentIsNotOwnedByClient_ThrowsException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedClientAsync(
            context,
            userId: 20,
            clientId: 200);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Appointments.Add(
            new Appointment
            {
                Id = 400,
                ClientId = 200,
                TherapistId = 300,
                Status =
                    AppointmentStatus.Completed
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var request =
            new CreateReviewDto
            {
                AppointmentId = 400,
                Rating = 5,
                Comment = "Excellent session."
            };

        var exception =
            await Record.ExceptionAsync(
                () =>
                    service.CreateAsync(
                        10,
                        request));

        Assert.NotNull(exception);

        Assert.Contains(
            "own appointment",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Empty(
            await context.Reviews
                .ToListAsync());
    }

    [Fact]
    public async Task CreateAsync_WhenAppointmentIsNotCompleted_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Appointments.Add(
            new Appointment
            {
                Id = 400,
                ClientId = 100,
                TherapistId = 300,
                Status =
                    AppointmentStatus.Accepted
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var request =
            new CreateReviewDto
            {
                AppointmentId = 400,
                Rating = 5,
                Comment = "Excellent session."
            };

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.CreateAsync(
                        10,
                        request));

        Assert.Contains(
            "completed",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Empty(
            await context.Reviews
                .ToListAsync());
    }

    [Fact]
    public async Task CreateAsync_WhenReviewAlreadyExists_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Appointments.Add(
            new Appointment
            {
                Id = 400,
                ClientId = 100,
                TherapistId = 300,
                Status =
                    AppointmentStatus.Completed
            });

        context.Reviews.Add(
            new Review
            {
                Id = 500,
                ClientId = 100,
                TherapistId = 300,
                AppointmentId = 400,
                Rating = 4,
                Comment = "Existing review.",
                IsApproved = false,
                ModerationStatus =
                    ReviewModerationStatus.Pending
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var request =
            new CreateReviewDto
            {
                AppointmentId = 400,
                Rating = 5,
                Comment = "Another review."
            };

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.CreateAsync(
                        10,
                        request));

        Assert.Contains(
            "already",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Equal(
            1,
            await context.Reviews.CountAsync());
    }

    [Fact]
    public async Task CreateAsync_WhenRequestIsValid_CreatesPendingReview()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Appointments.Add(
            new Appointment
            {
                Id = 400,
                ClientId = 100,
                TherapistId = 300,
                Status =
                    AppointmentStatus.Completed
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var request =
            new CreateReviewDto
            {
                AppointmentId = 400,
                Rating = 5,
                Comment =
                    "   Excellent session.   "
            };

        await service.CreateAsync(
            10,
            request);

        var review =
            await context.Reviews
                .SingleAsync();

        Assert.Equal(
            100,
            review.ClientId);

        Assert.Equal(
            300,
            review.TherapistId);

        Assert.Equal(
            400,
            review.AppointmentId);

        Assert.Equal(
            5,
            review.Rating);

        Assert.Equal(
            "Excellent session.",
            review.Comment);

        Assert.False(
            review.IsApproved);

        Assert.False(
            review.IsDeleted);

        Assert.Equal(
            ReviewModerationStatus.Pending,
            review.ModerationStatus);
    }

    [Fact]
    public async Task GetEligibilityAsync_WhenCompletedAppointmentHasNoReview_ReturnsCanReviewTrue()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Appointments.Add(
            new Appointment
            {
                Id = 400,
                ClientId = 100,
                TherapistId = 300,
                Status =
                    AppointmentStatus.Completed
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var result =
            await service.GetEligibilityAsync(
                10,
                400);

        Assert.True(
            result.CanReview);

        Assert.Equal(
            400,
            result.AppointmentId);

        Assert.Null(
            result.ExistingReviewId);
    }

    [Fact]
    public async Task GetEligibilityAsync_WhenReviewAlreadyExists_ReturnsExistingReviewInformation()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Appointments.Add(
            new Appointment
            {
                Id = 400,
                ClientId = 100,
                TherapistId = 300,
                Status =
                    AppointmentStatus.Completed
            });

        context.Reviews.Add(
            new Review
            {
                Id = 500,
                ClientId = 100,
                TherapistId = 300,
                AppointmentId = 400,
                Rating = 5,
                Comment = "Excellent.",
                ModerationStatus =
                    ReviewModerationStatus.Pending
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        var result =
            await service.GetEligibilityAsync(
                10,
                400);

        Assert.False(
            result.CanReview);

        Assert.Equal(
            500,
            result.ExistingReviewId);

        Assert.Equal(
            ReviewModerationStatus.Pending
                .ToString(),
            result.ModerationStatus);
    }

    [Fact]
    public async Task UpdateAsync_WhenReviewWasApproved_ResetsModerationToPending()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        var moderatedAt =
            DateTime.UtcNow.AddDays(-1);

        context.Reviews.Add(
            new Review
            {
                Id = 500,
                ClientId = 100,
                TherapistId = 300,
                AppointmentId = 400,
                Rating = 5,
                Comment = "Old comment.",
                IsApproved = true,
                ModerationStatus =
                    ReviewModerationStatus.Approved,
                ModeratedByUserId = 99,
                ModeratedAtUtc = moderatedAt,
                ModerationReason =
                    "Approved."
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        await service.UpdateAsync(
            10,
            500,
            new UpdateReviewDto
            {
                Rating = 4,
                Comment =
                    "   Updated comment.   "
            });

        var review =
            await context.Reviews
                .SingleAsync(
                    x => x.Id == 500);

        Assert.Equal(
            4,
            review.Rating);

        Assert.Equal(
            "Updated comment.",
            review.Comment);

        Assert.False(
            review.IsApproved);

        Assert.False(
            review.IsDeleted);

        Assert.Equal(
            ReviewModerationStatus.Pending,
            review.ModerationStatus);

        Assert.Null(
            review.ModeratedByUserId);

        Assert.Null(
            review.ModeratedAtUtc);

        Assert.Null(
            review.ModerationReason);

        Assert.NotNull(
            review.UpdatedAtUtc);
    }

    [Fact]
    public async Task DeleteAsync_WhenReviewIsOwnedByClient_SoftDeletesReview()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Reviews.Add(
            new Review
            {
                Id = 500,
                ClientId = 100,
                TherapistId = 300,
                AppointmentId = 400,
                Rating = 5,
                Comment = "Excellent.",
                IsApproved = true,
                ModerationStatus =
                    ReviewModerationStatus.Approved
            });

        await context.SaveChangesAsync();

        var service =
            new ReviewService(
                context,
                CreateNotificationMock().Object);

        await service.DeleteAsync(
            10,
            500);

        var review =
            await context.Reviews
                .SingleAsync(
                    x => x.Id == 500);

        Assert.True(
            review.IsDeleted);

        Assert.False(
            review.IsApproved);

        Assert.NotNull(
            review.ModeratedAtUtc);

        Assert.Equal(
            "Deleted by the review author.",
            review.ModerationReason);
    }

    [Fact]
    public async Task ReplyToReviewAsync_WhenReplyIsUnchanged_DoesNotPublishNotification()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Reviews.Add(
            new Review
            {
                Id = 500,
                ClientId = 100,
                TherapistId = 300,
                AppointmentId = 400,
                Rating = 5,
                Comment = "Excellent.",
                TherapistReply =
                    "Thank you!",
                ModerationStatus =
                    ReviewModerationStatus.Approved
            });

        await context.SaveChangesAsync();

        var notificationMock =
            CreateNotificationMock();

        var service =
            new ReviewService(
                context,
                notificationMock.Object);

        await service.ReplyToReviewAsync(
            30,
            500,
            new ReplyToReviewDto
            {
                Reply = "Thank you!"
            });

        notificationMock.Verify(
            x =>
                x.PublishAsync(
                    It.IsAny<int>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<int?>(),
                    It.IsAny<NotificationActionType>(),
                    It.IsAny<int?>(),
                    It.IsAny<bool>(),
                    It.IsAny<bool>(),
                    It.IsAny<Guid?>(),
                    It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ReplyToReviewAsync_WhenReplyChanges_StoresReplyAndPublishesNotification()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 100);

        await SeedTherapistAsync(
            context,
            userId: 30,
            therapistId: 300);

        context.Reviews.Add(
            new Review
            {
                Id = 500,
                ClientId = 100,
                TherapistId = 300,
                AppointmentId = 400,
                Rating = 5,
                Comment = "Excellent.",
                ModerationStatus =
                    ReviewModerationStatus.Approved
            });

        await context.SaveChangesAsync();

        var notificationMock =
            CreateNotificationMock();

        var service =
            new ReviewService(
                context,
                notificationMock.Object);

        await service.ReplyToReviewAsync(
            30,
            500,
            new ReplyToReviewDto
            {
                Reply =
                    "   Thank you for your feedback!   "
            });

        var review =
            await context.Reviews
                .SingleAsync(
                    x => x.Id == 500);

        Assert.Equal(
            "Thank you for your feedback!",
            review.TherapistReply);

        Assert.NotNull(
            review.TherapistReplyCreatedAtUtc);

        notificationMock.Verify(
            x =>
                x.PublishAsync(
                    10,
                    "Therapist replied to your review",
                    "Your therapist has replied to one of your reviews.",
                    null,
                    NotificationActionType.Review,
                    500,
                    false,
                    true,
                    null,
                    It.IsAny<CancellationToken>()),
            Times.Once);
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    Guid.NewGuid().ToString())
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static Mock<
        IBusinessNotificationService>
        CreateNotificationMock()
    {
        var mock =
            new Mock<
                IBusinessNotificationService>();

        mock.Setup(
                x =>
                    x.PublishAsync(
                        It.IsAny<int>(),
                        It.IsAny<string>(),
                        It.IsAny<string>(),
                        It.IsAny<int?>(),
                        It.IsAny<NotificationActionType>(),
                        It.IsAny<int?>(),
                        It.IsAny<bool>(),
                        It.IsAny<bool>(),
                        It.IsAny<Guid?>(),
                        It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        return mock;
    }

    private static async Task<Client>
        SeedClientAsync(
            ApplicationDbContext context,
            int userId,
            int clientId)
    {
        var user =
            new ApplicationUser
            {
                Id = userId,
                UserName =
                    $"client{userId}@test.com",
                Email =
                    $"client{userId}@test.com",
                FirstName = "Client",
                LastName =
                    userId.ToString(),
                DateOfBirth =
                    new DateTime(
                        2000,
                        1,
                        1),
                CreatedAtUtc =
                    DateTime.UtcNow,
                IsActive = true
            };

        var client =
            new Client
            {
                Id = clientId,
                UserId = userId,
                User = user
            };

        context.Users.Add(user);

        context.Clients.Add(client);

        await context.SaveChangesAsync();

        return client;
    }

    private static async Task<Therapist>
        SeedTherapistAsync(
            ApplicationDbContext context,
            int userId,
            int therapistId)
    {
        var user =
            new ApplicationUser
            {
                Id = userId,
                UserName =
                    $"therapist{userId}@test.com",
                Email =
                    $"therapist{userId}@test.com",
                FirstName = "Therapist",
                LastName =
                    userId.ToString(),
                DateOfBirth =
                    new DateTime(
                        1990,
                        1,
                        1),
                CreatedAtUtc =
                    DateTime.UtcNow,
                IsActive = true
            };

        var therapist =
            new Therapist
            {
                Id = therapistId,
                UserId = userId,
                User = user,
                Biography =
                    "Test biography",
                Specialization =
                    "Test specialization",
                PricePerSession = 50m,
                HourlyRate = 50m,
                VerificationStatus =
                    TherapistVerificationStatus.Approved
            };

        context.Users.Add(user);

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist;
    }
}