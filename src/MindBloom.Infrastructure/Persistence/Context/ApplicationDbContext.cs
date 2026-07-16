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
    public DbSet<Favorite> Favorites => Set<Favorite>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Review> Reviews => Set<Review>();
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

        builder.Entity<Notification>()
            .HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<Review>()
            .HasOne(x => x.Client)
            .WithMany()
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Restrict);

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

            entity.HasIndex(x => x.PublishedAtUtc);

            entity.HasIndex(x => new
            {
                x.IsPublished,
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