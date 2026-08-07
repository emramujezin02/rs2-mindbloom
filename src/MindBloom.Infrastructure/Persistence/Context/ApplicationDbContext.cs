using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using System.Collections.Generic;
using System.Reflection.Emit;


namespace MindBloom.Infrastructure.Persistence.Context;

public class ApplicationDbContext : IdentityDbContext<ApplicationUser, IdentityRole<int>, int>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }
    public DbSet<PasswordResetCode> PasswordResetCodes { get; set; }
    public DbSet<Client> Clients => Set<Client>();
    public DbSet<MoodEntry> MoodEntries => Set<MoodEntry>();
    public DbSet<Therapist> Therapists => Set<Therapist>();
    public DbSet<TherapistAvailability> TherapistAvailabilities => Set<TherapistAvailability>();
    public DbSet<Appointment> Appointments => Set<Appointment>();

    public DbSet<StripeWebhookEvent>
    StripeWebhookEvents =>
        Set<StripeWebhookEvent>();
    public DbSet<Favorite> Favorites => Set<Favorite>();
    public DbSet<FcmDeviceToken>
    FcmDeviceTokens =>
        Set<FcmDeviceToken>();
    public DbSet<TwoFactorLoginChallenge>
    TwoFactorLoginChallenges
    {
        get;
        set;
    }
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<ProcessedMessage>
    ProcessedMessages =>
        Set<ProcessedMessage>();
    public DbSet<AdminAuditLog> AdminAuditLogs =>
    Set<AdminAuditLog>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<RefreshToken> RefreshTokens { get; set; }
    public DbSet<TherapistDocument>TherapistDocuments { get; set; }
    public DbSet<AppointmentNote> AppointmentNotes { get; set; }
    public DbSet<TherapistUnavailableDate> TherapistUnavailableDates{ get; set; }
    public DbSet<ClientMembership> ClientMemberships { get; set; }
    public DbSet<EmailVerificationCode> EmailVerificationCodes { get; set; }
    public DbSet<MembershipUsage> MembershipUsages { get; set; }
    public DbSet<Article> Articles => Set<Article>();
    public DbSet<Workshop> Workshops => Set<Workshop>();
    public DbSet<WorkshopRegistration>WorkshopRegistrations => Set<WorkshopRegistration>();
    public DbSet<MembershipPayment> MembershipPayments =>Set<MembershipPayment>();
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationParticipant> ConversationParticipants => Set<ConversationParticipant>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<TherapistVerificationAudit> TherapistVerificationAudits=> Set<TherapistVerificationAudit>();
    public DbSet<AppointmentStatusAudit> AppointmentStatusAudits => Set<AppointmentStatusAudit>();
    public DbSet<ReviewModerationAudit> ReviewModerationAudits => Set<ReviewModerationAudit>();
    public DbSet<ArticleCategory> ArticleCategories => Set<ArticleCategory>();
    public DbSet<PaymentAdminAudit> PaymentAdminAudits =>
    Set<PaymentAdminAudit>();

    public DbSet<MembershipPlan> MembershipPlans =>
    Set<MembershipPlan>();

    public DbSet<MembershipPlanAudit> MembershipPlanAudits =>
        Set<MembershipPlanAudit>();
    public DbSet<UserAudit> UserAudits => Set<UserAudit>();
    public DbSet<UserSettings> UserSettings =>
    Set<UserSettings>();

    public DbSet<TherapistTherapyApproach>
    TherapistTherapyApproaches =>
        Set<TherapistTherapyApproach>();
    public DbSet<ClientTherapyApproach>
    ClientTherapyApproaches =>
        Set<ClientTherapyApproach>();
    public DbSet<TherapistSpecialization> TherapistSpecializations => Set<TherapistSpecialization>();
    public DbSet<PrivateJournalEntry>
    PrivateJournalEntries =>
        Set<PrivateJournalEntry>();
    public DbSet<TherapyApproach> TherapyApproaches =>
    Set<TherapyApproach>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<Therapist>()
            .HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Client>()
            .HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Appointment>()
            .HasOne(x => x.Client)
            .WithMany(x => x.Appointments)
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Appointment>()
            .HasOne(x => x.Therapist)
            .WithMany(x => x.Appointments)
            .HasForeignKey(x => x.TherapistId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<TwoFactorLoginChallenge>(
    entity =>
    {
        entity.Property(x =>
                x.ChallengeHash)
            .IsRequired()
            .HasMaxLength(64);

        entity.Property(x =>
                x.CodeHash)
            .IsRequired()
            .HasMaxLength(1000);

        entity.Property(x =>
                x.IssuedAtUtc)
            .IsRequired();

        entity.Property(x =>
                x.ExpiresAtUtc)
            .IsRequired();

        entity.Property(x =>
                x.FailedAttempts)
            .HasDefaultValue(0);

        entity.Property(x =>
                x.MaximumAttempts)
            .HasDefaultValue(5);

        entity.Property(x =>
                x.IsUsed)
            .HasDefaultValue(false);

        entity.HasOne(x =>
                x.User)
            .WithMany(x =>
                x.TwoFactorLoginChallenges)
            .HasForeignKey(x =>
                x.UserId)
            .OnDelete(
                DeleteBehavior.Cascade);

        entity.HasIndex(x =>
                x.ChallengeHash)
            .IsUnique();

        entity.HasIndex(x => new
        {
            x.UserId,
            x.IsUsed,
            x.ExpiresAtUtc
        });
    });

        builder.Entity<StripeWebhookEvent>(
    entity =>
    {
        entity.Property(x =>
                x.StripeEventId)
            .IsRequired()
            .HasMaxLength(255);

        entity.Property(x =>
                x.EventType)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x =>
                x.StripePaymentIntentId)
            .HasMaxLength(255);

        entity.Property(x =>
                x.ReceivedAtUtc)
            .IsRequired();

        entity.Property(x =>
                x.FailureReason)
            .HasMaxLength(1000);

        entity.HasIndex(x =>
                x.StripeEventId)
            .IsUnique();

        entity.HasIndex(x =>
                x.StripePaymentIntentId);

        entity.HasIndex(x => new
        {
            x.IsProcessed,
            x.ReceivedAtUtc
        });
    });

        builder.Entity<RefreshToken>(
    entity =>
    {
        entity.Property(x =>
                x.TokenHash)
            .IsRequired()
            .HasMaxLength(64);

        entity.Property(x =>
                x.SessionId)
            .IsRequired()
            .HasMaxLength(64);

        entity.Property(x =>
                x.ReplacedByTokenHash)
            .HasMaxLength(64);

        entity.Property(x =>
                x.IssuedAtUtc)
            .IsRequired();

        entity.Property(x =>
                x.ExpiresAtUtc)
            .IsRequired();

        entity.HasOne(x =>
                x.User)
            .WithMany()
            .HasForeignKey(x =>
                x.UserId)
            .OnDelete(
                DeleteBehavior.Cascade);

        entity.HasIndex(x =>
                x.TokenHash)
            .IsUnique();

        entity.HasIndex(x => new
        {
            x.UserId,
            x.SessionId
        });

        entity.HasIndex(x =>
            x.ExpiresAtUtc);
    });

        builder.Entity<FcmDeviceToken>(
    entity =>
    {
        entity.Property(x =>
                x.Token)
            .IsRequired()
            .HasMaxLength(2000);

        entity.Property(x =>
                x.Platform)
            .IsRequired()
            .HasMaxLength(50);

        entity.Property(x =>
                x.DeviceId)
            .HasMaxLength(500);

        entity.Property(x =>
                x.IsActive)
            .HasDefaultValue(true);

        entity.Property(x =>
                x.RegisteredAtUtc)
            .IsRequired();

        entity.HasOne(x =>
                x.User)
            .WithMany(x =>
                x.FcmDeviceTokens)
            .HasForeignKey(x =>
                x.UserId)
            .OnDelete(
                DeleteBehavior.Cascade);

        entity.HasIndex(x =>
                x.Token)
            .IsUnique();

        entity.HasIndex(x => new
        {
            x.UserId,
            x.IsActive,
            x.IsDeleted
        });

        entity.HasIndex(x =>
            x.DeviceId);
    });

        builder.Entity<Payment>()
            .HasOne(x => x.Appointment)
            .WithOne(x => x.Payment)
            .HasForeignKey<Payment>(x => x.AppointmentId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<TherapistAvailability>()
            .HasOne(x => x.Therapist)
            .WithMany(x => x.Availabilities)
            .HasForeignKey(x => x.TherapistId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<ProcessedMessage>(
    entity =>
    {
        entity.Property(x =>
                x.MessageId)
            .IsRequired();

        entity.Property(x =>
                x.ConsumerName)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x =>
                x.MessageType)
            .IsRequired()
            .HasMaxLength(250);

        entity.Property(x =>
                x.CorrelationId);

        entity.Property(x =>
                x.ProcessedAtUtc)
            .IsRequired();

        entity.HasIndex(x => new
        {
            x.MessageId,
            x.ConsumerName
        })
            .IsUnique();

        entity.HasIndex(x =>
            x.ProcessedAtUtc);

        entity.HasIndex(x =>
            x.CorrelationId);
    });

        builder.Entity<UserAudit>(entity =>
        {
            entity.Property(x => x.Action)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(x => x.PreviousValues)
                .HasMaxLength(4000);

            entity.Property(x => x.NewValues)
                .HasMaxLength(4000);

            entity.Property(x => x.Reason)
                .HasMaxLength(500);

            entity.HasOne(x => x.TargetUser)
                .WithMany(x => x.ReceivedUserAudits)
                .HasForeignKey(x => x.TargetUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.ChangedByUser)
                .WithMany(x => x.PerformedUserAudits)
                .HasForeignKey(x => x.ChangedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => x.TargetUserId);

            entity.HasIndex(x => x.ChangedByUserId);

            entity.HasIndex(x => x.ChangedAtUtc);
        });

        builder.Entity<Notification>(
            entity =>
            {
                entity.Property(x =>
                        x.Title)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(x =>
                        x.Message)
                    .IsRequired()
                    .HasMaxLength(2000);

                entity.Property(x =>
                        x.ActionType)
                    .HasConversion<int>();

                entity.HasOne(x =>
                        x.User)
                    .WithMany()
                    .HasForeignKey(x =>
                        x.UserId)
                    .OnDelete(
                        DeleteBehavior.Cascade);

                entity.HasOne(x =>
                        x.Appointment)
                    .WithMany()
                    .HasForeignKey(x =>
                        x.AppointmentId)
                    .OnDelete(
                        DeleteBehavior.SetNull);

                entity.HasIndex(x => new
                {
                    x.UserId,
                    x.IsRead,
                    x.CreatedAtUtc
                });

                entity.HasIndex(x =>
                    x.ResourceId);

                entity.HasIndex(x => new
                {
                    x.UserId,
                    x.CreatedAtUtc
                });
            });

        builder.Entity<Review>()
            .HasOne(x => x.Client)
            .WithMany()
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<AdminAuditLog>(
    entity =>
    {
        entity.Property(x =>
                x.AdminName)
            .IsRequired()
            .HasMaxLength(200);

        entity.Property(x =>
                x.AdminEmail)
            .IsRequired()
            .HasMaxLength(256);

        entity.Property(x =>
                x.Action)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x =>
                x.EntityType)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x =>
                x.EntityId)
            .HasMaxLength(100);

        entity.Property(x =>
                x.HttpMethod)
            .IsRequired()
            .HasMaxLength(20);

        entity.Property(x =>
                x.RequestPath)
            .IsRequired()
            .HasMaxLength(1000);

        entity.Property(x =>
                x.PreviousValues)
            .HasMaxLength(4000);

        entity.Property(x =>
                x.NewValues)
            .HasMaxLength(4000);

        entity.Property(x =>
                x.IpAddress)
            .HasMaxLength(100);

        entity.Property(x =>
                x.CorrelationId)
            .IsRequired()
            .HasMaxLength(100);

        entity.Property(x =>
                x.ResultMessage)
            .HasMaxLength(1000);

        entity.HasOne(x =>
                x.AdminUser)
            .WithMany(x =>
                x.AdminAuditLogs)
            .HasForeignKey(x =>
                x.AdminUserId)
            .OnDelete(
                DeleteBehavior.SetNull);

        entity.HasIndex(x =>
            x.AdminUserId);

        entity.HasIndex(x =>
            x.Action);

        entity.HasIndex(x =>
            x.EntityType);

        entity.HasIndex(x =>
            x.OccurredAtUtc);

        entity.HasIndex(x =>
            x.IsSuccessful);

        entity.HasIndex(x =>
            x.CorrelationId);

        entity.HasIndex(x => new
        {
            x.EntityType,
            x.EntityId
        });
    });

        builder.Entity<ArticleCategory>(entity =>
        {
            entity.Property(x => x.Name)
                .IsRequired()
                .HasMaxLength(100);

            entity.Property(x => x.Description)
                .HasMaxLength(500);

            entity.Property(x => x.IsActive)
                .HasDefaultValue(true);

            entity.HasIndex(x => x.Name)
                .IsUnique()
                .HasFilter("[IsDeleted] = 0");

            entity.HasIndex(x => new
            {
                x.IsActive,
                x.IsDeleted
            });
        });

        builder.Entity<MembershipPlan>(
    entity =>
    {
        entity.Property(x => x.Name)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x => x.Description)
            .IsRequired()
            .HasMaxLength(1000);

        entity.Property(x => x.Price)
            .HasPrecision(18, 2);

        entity.Property(x => x.DiscountPercentage)
            .HasPrecision(5, 2);

        entity.Property(x => x.BenefitsJson)
            .IsRequired()
            .HasMaxLength(4000);

        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);

        entity.HasIndex(x => new
        {
            x.PlanType,
            x.IsDeleted
        })
        .IsUnique()
        .HasFilter("[IsDeleted] = 0");

        entity.HasIndex(x => new
        {
            x.IsActive,
            x.IsDeleted
        });
    });

        builder.Entity<MembershipPlanAudit>(
            entity =>
            {
                entity.Property(x => x.Action)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(x => x.PreviousValues)
                    .HasMaxLength(4000);

                entity.Property(x => x.NewValues)
                    .HasMaxLength(4000);

                entity.Property(x => x.Reason)
                    .HasMaxLength(500);

                entity.HasOne(x => x.MembershipPlan)
                    .WithMany(x => x.Audits)
                    .HasForeignKey(x => x.MembershipPlanId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(x => x.ChangedByUser)
                    .WithMany()
                    .HasForeignKey(x => x.ChangedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(x => new
                {
                    x.MembershipPlanId,
                    x.ChangedAtUtc
                });

                entity.HasIndex(x => x.ChangedByUserId);
            });

        builder.Entity<Review>()
            .HasOne(x => x.Therapist)
            .WithMany(x => x.Reviews)
            .HasForeignKey(x => x.TherapistId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Favorite>()
            .HasOne(x => x.Client)
            .WithMany()
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<Favorite>()
            .HasOne(x => x.Therapist)
            .WithMany()
            .HasForeignKey(x => x.TherapistId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<TherapyApproach>(entity =>
        {
            entity.Property(x => x.Name)
                .IsRequired()
                .HasMaxLength(150);

            entity.Property(x => x.Description)
                .HasMaxLength(500);

            entity.Property(x => x.IsActive)
                .HasDefaultValue(true);

            entity.HasIndex(x => x.Name)
                .IsUnique()
                .HasFilter("[IsDeleted] = 0");

            entity.HasIndex(x => new
            {
                x.IsActive,
                x.IsDeleted
            });
        });

        builder.Entity<UserSettings>(
    entity =>
    {
        entity.HasOne(x => x.User)
            .WithOne(x => x.Settings)
            .HasForeignKey<UserSettings>(
                x => x.UserId)
            .OnDelete(
                DeleteBehavior.Cascade);

        entity.Property(x =>
                x.NotificationsEnabled)
            .HasDefaultValue(true);

        entity.Property(x =>
                x.ShowProfilePublicly)
            .HasDefaultValue(true);

        entity.Property(x =>
        x.ShareMoodAndEmotionsWithTherapists)
    .HasDefaultValue(false);

        entity.HasIndex(x => x.UserId)
            .IsUnique();
    });

        builder.Entity<TherapistTherapyApproach>(entity =>
        {
            entity.HasOne(x => x.Therapist)
                .WithMany(x => x.TherapyApproaches)
                .HasForeignKey(x => x.TherapistId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.TherapyApproach)
                .WithMany(x => x.TherapistTherapyApproaches)
                .HasForeignKey(x => x.TherapyApproachId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => new
            {
                x.TherapistId,
                x.TherapyApproachId
            })
            .IsUnique();

            entity.HasIndex(x => new
            {
                x.TherapistId,
                x.IsDeleted
            });
        });

        builder.Entity<ClientMembership>(
    entity =>
    {
        entity.Property(x => x.Price)
            .HasPrecision(18, 2);

        entity.HasOne(x => x.Client)
            .WithMany()
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasOne(x => x.Therapist)
            .WithMany()
            .HasForeignKey(x => x.TherapistId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasIndex(x => new
        {
            x.ClientId,
            x.TherapistId,
            x.IsActive
        });

        entity.HasIndex(x => new
        {
            x.ClientId,
            x.TherapistId,
            x.PlanType,
            x.IsDeleted
        });
    });

        builder.Entity<MembershipUsage>(
    entity =>
    {
        entity.HasOne(x =>
                x.ClientMembership)
            .WithMany(x =>
                x.Usages)
            .HasForeignKey(x =>
                x.ClientMembershipId)
            .OnDelete(
                DeleteBehavior.Restrict);

        entity.HasOne(x =>
                x.Appointment)
            .WithMany()
            .HasForeignKey(x =>
                x.AppointmentId)
            .OnDelete(
                DeleteBehavior.Restrict);

        entity.Property(x =>
                x.Status)
            .HasDefaultValue(
                MembershipUsageStatus
                    .Consumed);

        entity.Property(x =>
                x.ResolutionReason)
            .HasMaxLength(500);

        entity.HasIndex(x =>
                x.AppointmentId)
            .IsUnique();

        entity.HasIndex(x => new
        {
            x.ClientMembershipId,
            x.Status
        });
    });

        builder.Entity<EmailVerificationCode>(
        entity =>
        {
            entity.Property(x => x.CodeHash)
                .IsRequired();

            entity.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(x => new
            {
                x.UserId,
                x.IsUsed,
                x.ExpiresAtUtc
            });
        });

        builder.Entity<PaymentAdminAudit>(
    entity =>
    {
        entity.Property(x => x.PaymentType)
            .IsRequired()
            .HasMaxLength(30);

        entity.Property(x => x.Action)
            .IsRequired()
            .HasMaxLength(100);

        entity.Property(x => x.Reason)
            .IsRequired()
            .HasMaxLength(500);

        entity.HasOne(x => x.AdminUser)
            .WithMany()
            .HasForeignKey(x => x.AdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasIndex(x => new
        {
            x.PaymentType,
            x.PaymentId,
            x.PerformedAtUtc
        });

        entity.HasIndex(x => x.AdminUserId);
    });

        builder.Entity<Article>(entity =>
        {
            entity.Property(x => x.Title)
                .IsRequired()
                .HasMaxLength(200);

            entity.Property(x => x.Description)
                .IsRequired()
                .HasMaxLength(500);

            entity.Property(x => x.Content)
                .IsRequired();

            entity.Property(x => x.ImageUrl)
                .HasMaxLength(1000);

            entity.HasOne(x => x.AuthorUser)
                .WithMany()
                .HasForeignKey(x => x.AuthorUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Therapist)
                .WithMany(x => x.Articles)
                .HasForeignKey(x => x.TherapistId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.ArticleCategory)
    .WithMany(x => x.Articles)
    .HasForeignKey(x => x.ArticleCategoryId)
    .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => new
            {
                x.ArticleCategoryId,
                x.IsPublished,
                x.IsDeleted
            });

            entity.HasIndex(x => x.PublishedAtUtc);

            entity.HasIndex(x => new
            {
                x.IsPublished,
                x.IsDeleted
            });
        });

        builder.Entity<ClientTherapyApproach>(
    entity =>
    {
        entity.HasOne(x =>
                x.Client)
            .WithMany(x =>
                x.PreferredTherapyApproaches)
            .HasForeignKey(x =>
                x.ClientId)
            .OnDelete(
                DeleteBehavior.Cascade);

        entity.HasOne(x =>
                x.TherapyApproach)
            .WithMany(x =>
                x.ClientTherapyApproaches)
            .HasForeignKey(x =>
                x.TherapyApproachId)
            .OnDelete(
                DeleteBehavior.Restrict);

        entity.HasIndex(x => new
        {
            x.ClientId,
            x.TherapyApproachId
        })
            .IsUnique();

        entity.HasIndex(x => new
        {
            x.ClientId,
            x.IsDeleted
        });
    });

        builder.Entity<Workshop>(entity =>
        {
            entity.Property(x => x.Title)
                .IsRequired()
                .HasMaxLength(150);

            entity.Property(x => x.Description)
                .IsRequired()
                .HasMaxLength(2000);

            entity.Property(x => x.OnlineLink)
                .HasMaxLength(1000);

            entity.Property(x => x.Location)
                .HasMaxLength(300);

            entity.Property(x => x.Price)
                .HasPrecision(18, 2);

            entity.Property(x => x.StatusChangeReason)
                .HasMaxLength(500);

            entity.HasOne(x => x.OrganizerUser)
                .WithMany()
                .HasForeignKey(x => x.OrganizerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Therapist)
                .WithMany(x => x.Workshops)
                .HasForeignKey(x => x.TherapistId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.StatusChangedByUser)
                .WithMany()
                .HasForeignKey(x => x.StatusChangedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => x.StartUtc);

            entity.HasIndex(x => new
            {
                x.Status,
                x.IsDeleted
            });
        });

        builder.Entity<WorkshopRegistration>(entity =>
        {
            entity.HasOne(x => x.Workshop)
                .WithMany(x => x.Registrations)
                .HasForeignKey(x => x.WorkshopId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Client)
                .WithMany(x => x.WorkshopRegistrations)
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => new
            {
                x.WorkshopId,
                x.ClientId
            })
            .IsUnique();

            entity.HasIndex(x => new
            {
                x.WorkshopId,
                x.Status
            });
        });



        builder.Entity<Payment>(
     entity =>
     {
         entity.HasOne(x =>
                 x.Appointment)
             .WithOne(x =>
                 x.Payment)
             .HasForeignKey<Payment>(x =>
                 x.AppointmentId)
             .OnDelete(
                 DeleteBehavior.Restrict);

         entity.Property(x =>
                 x.StripePaymentIntentId)
             .IsRequired()
             .HasMaxLength(255);

         entity.Property(x =>
                 x.StripeRefundId)
             .HasMaxLength(255);

         entity.Property(x =>
                 x.RefundReason)
             .HasMaxLength(500);

         entity.Property(x =>
                 x.RefundFailureReason)
             .HasMaxLength(1000);

         entity.HasIndex(x =>
                 x.StripePaymentIntentId)
             .IsUnique();

         entity.HasIndex(x =>
                 x.AppointmentId)
             .IsUnique();

         entity.HasIndex(x =>
                 x.StripeRefundId)
             .IsUnique()
             .HasFilter(
                 "[StripeRefundId] IS NOT NULL");
     });

        builder.Entity<PrivateJournalEntry>(
    entity =>
    {
        entity.Property(x =>
                x.Title)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x =>
                x.Content)
            .IsRequired()
            .HasMaxLength(10000);

        entity.Property(x =>
                x.EntryDateUtc)
            .IsRequired();

        entity.HasOne(x =>
                x.Client)
            .WithMany()
            .HasForeignKey(x =>
                x.ClientId)
            .OnDelete(
                DeleteBehavior.Restrict);

        entity.HasOne(x =>
                x.MoodEntry)
            .WithMany()
            .HasForeignKey(x =>
                x.MoodEntryId)
            .OnDelete(
                DeleteBehavior.SetNull);

        entity.HasIndex(x => new
        {
            x.ClientId,
            x.EntryDateUtc
        });

        entity.HasIndex(x => new
        {
            x.ClientId,
            x.IsDeleted
        });
    });

        builder.Entity<MembershipPayment>(
    entity =>
    {
        entity.Property(x => x.Amount)
            .HasPrecision(18, 2);

        entity.Property(x => x.Currency)
            .IsRequired()
            .HasMaxLength(10);

        entity.Property(x =>
                x.StripePaymentIntentId)
            .IsRequired()
            .HasMaxLength(255);

        entity.HasOne(x =>
                x.ClientMembership)
            .WithOne(x =>
                x.Payment)
            .HasForeignKey<MembershipPayment>(
                x =>
                    x.ClientMembershipId)
            .OnDelete(
                DeleteBehavior.Restrict);

        entity.HasIndex(x =>
                x.ClientMembershipId)
            .IsUnique();

        entity.HasIndex(x =>
                x.StripePaymentIntentId)
            .IsUnique();
    });

        builder.Entity<Conversation>(
    entity =>
    {
        entity.HasOne(x =>
                x.Appointment)
            .WithOne(x =>
                x.Conversation)
            .HasForeignKey<Conversation>(
                x => x.AppointmentId)
            .OnDelete(
                DeleteBehavior.Restrict);

        entity.HasIndex(x =>
                x.AppointmentId)
            .IsUnique();

        entity.HasIndex(x =>
            new
            {
                x.IsClosed,
                x.IsDeleted
            });
    });

        builder.Entity<ConversationParticipant>(
            entity =>
            {
                entity.HasOne(x =>
                        x.Conversation)
                    .WithMany(x =>
                        x.Participants)
                    .HasForeignKey(x =>
                        x.ConversationId)
                    .OnDelete(
                        DeleteBehavior.Cascade);

                entity.HasOne(x =>
                        x.User)
                    .WithMany()
                    .HasForeignKey(x =>
                        x.UserId)
                    .OnDelete(
                        DeleteBehavior.Restrict);

                entity.HasIndex(x =>
                    new
                    {
                        x.ConversationId,
                        x.UserId
                    })
                    .IsUnique();

                entity.HasIndex(x =>
                    new
                    {
                        x.UserId,
                        x.IsActive,
                        x.IsDeleted
                    });
            });

        builder.Entity<ChatMessage>(
            entity =>
            {
                entity.Property(x =>
                        x.Content)
                    .IsRequired()
                    .HasMaxLength(2000);

                entity.HasOne(x =>
                        x.Conversation)
                    .WithMany(x =>
                        x.Messages)
                    .HasForeignKey(x =>
                        x.ConversationId)
                    .OnDelete(
                        DeleteBehavior.Cascade);

                entity.HasOne(x =>
                        x.SenderUser)
                    .WithMany()
                    .HasForeignKey(x =>
                        x.SenderUserId)
                    .OnDelete(
                        DeleteBehavior.Restrict);

                entity.Property(x =>
        x.ClientMessageId)
    .HasMaxLength(100);

                entity.HasIndex(x => new
                {
                    x.ConversationId,
                    x.ClientMessageId
                })
                    .IsUnique()
                    .HasFilter(
                        "[ClientMessageId] IS NOT NULL");

                entity.HasIndex(x =>
                    new
                    {
                        x.ConversationId,
                        x.SentAtUtc
                    });

                entity.HasIndex(x =>
                    new
                    {
                        x.SenderUserId,
                        x.SentAtUtc
                    });
            });

        builder.Entity<TherapistVerificationAudit>(
    entity =>
    {
        entity.Property(x => x.Notes)
            .HasMaxLength(1000);

        entity.HasOne(x => x.Therapist)
            .WithMany(x => x.VerificationAudits)
            .HasForeignKey(x => x.TherapistId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasOne(x => x.AdminUser)
            .WithMany()
            .HasForeignKey(x => x.AdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasIndex(x => new
        {
            x.TherapistId,
            x.ChangedAtUtc
        });
    });

        builder.Entity<Review>(entity =>
        {
            entity.Property(x => x.Comment)
                .IsRequired()
                .HasMaxLength(1000);

            entity.Property(x => x.TherapistReply)
                .HasMaxLength(1000);

            entity.Property(x => x.ModerationReason)
                .HasMaxLength(1000);

            entity.HasOne(x => x.ModeratedByUser)
                .WithMany()
                .HasForeignKey(x => x.ModeratedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.Property(x => x.IsApproved)
    .HasDefaultValue(false);

            entity.HasOne(x => x.Appointment)
    .WithOne()
    .HasForeignKey<Review>(x => x.AppointmentId)
    .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => x.AppointmentId)
                .IsUnique()
                .HasFilter("[IsDeleted] = 0");

            entity.HasIndex(x => new
            {
                x.IsApproved,
                x.IsDeleted,
                x.CreatedAtUtc
            });
        });

        builder.Entity<ReviewModerationAudit>(
    entity =>
    {
        entity.Property(x => x.Reason)
            .IsRequired()
            .HasMaxLength(1000);

        entity.HasOne(x => x.Review)
            .WithMany(x => x.ModerationAudits)
            .HasForeignKey(x => x.ReviewId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasOne(x => x.AdminUser)
            .WithMany()
            .HasForeignKey(x => x.AdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasIndex(x => new
        {
            x.ReviewId,
            x.PerformedAtUtc
        });
    });

        builder.Entity<TherapistSpecialization>(
    entity =>
    {
        entity.Property(x => x.Name)
            .IsRequired()
            .HasMaxLength(150);

        entity.Property(x => x.Description)
            .HasMaxLength(500);

        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);

        entity.HasIndex(x => x.Name)
            .IsUnique()
            .HasFilter("[IsDeleted] = 0");

        entity.HasIndex(x => new
        {
            x.IsActive,
            x.IsDeleted
        });
    });

        builder.Entity<MoodEntry>(entity =>
        {
            entity.Property(x => x.MoodScore)
                .IsRequired();

            entity.Property(x => x.Emotion)
                .IsRequired()
                .HasMaxLength(500);

            entity.Property(x => x.Notes)
                .HasMaxLength(500);

            entity.HasOne(x => x.Client)
                .WithMany(x => x.MoodEntries)
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(x => new
            {
                x.ClientId,
                x.CreatedAtUtc,
                x.IsDeleted
            });
        });

        builder.Entity<Therapist>()
            .HasOne(x => x.SpecializationReference)
            .WithMany(x => x.Therapists)
            .HasForeignKey(x => x.SpecializationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<AppointmentStatusAudit>(
    entity =>
    {
        entity.Property(x => x.Action)
            .IsRequired()
            .HasMaxLength(100);

        entity.Property(x => x.Reason)
            .HasMaxLength(1000);

        entity.HasOne(x => x.Appointment)
            .WithMany(x => x.StatusAudits)
            .HasForeignKey(x => x.AppointmentId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasOne(x => x.ChangedByUser)
            .WithMany()
            .HasForeignKey(x => x.ChangedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        entity.HasIndex(x => new
        {
            x.AppointmentId,
            x.ChangedAtUtc
        });
    });

        builder.Entity<Client>(entity =>
        {
            entity.Property(x => x.Location)
                .HasMaxLength(200);

            entity.Property(x => x.PreferredTherapistGender)
                .HasMaxLength(20);

            entity.Property(x => x.PreferredSessionType)
                .HasMaxLength(20);

            entity.Property(x => x.MinimumPricePerSession)
                .HasPrecision(18, 2);

            entity.Property(x => x.MaximumPricePerSession)
                .HasPrecision(18, 2);

            entity.Property(x => x.PreferredLanguages)
                .HasMaxLength(1000);

            entity.Property(x =>
        x.AssessmentFocusAreas)
    .HasMaxLength(1500);

            entity.Property(x =>
                    x.PreferredDays)
                .HasMaxLength(50);

            entity.HasIndex(x => new
            {
                x.UserId,
                x.HasCompletedOnboarding,
                x.IsDeleted
            });
        });

        builder.Entity<Therapist>()
    .Property(x => x.Specialization)
    .IsRequired()
    .HasMaxLength(150);

        builder.Entity<Therapist>()
    .Property(x => x.Location)
    .HasMaxLength(200);

        builder.Entity<Therapist>()
            .Property(x => x.Languages)
            .HasMaxLength(1000);
    }

    public override async Task<int> SaveChangesAsync(
    CancellationToken cancellationToken = default)
    {
        var entries = ChangeTracker
            .Entries<BaseEntity>();

        foreach (var entry in entries)
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedAtUtc =
                    DateTime.UtcNow;
            }

            if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAtUtc =
                    DateTime.UtcNow;
            }
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}