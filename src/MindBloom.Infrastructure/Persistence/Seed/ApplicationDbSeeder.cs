using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Persistence.Seed;

public static class ApplicationDbSeeder
{
    public static async Task SeedAsync(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole<int>> roleManager)
    {

        if (!await context.TherapistSpecializations.AnyAsync())
        {
            context.TherapistSpecializations.AddRange(
                new TherapistSpecialization
                {
                    Name = "Anxiety Disorders",
                    Description =
                        "Support and treatment for anxiety, panic attacks and related disorders.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Depression",
                    Description =
                        "Assessment and treatment of depressive symptoms and mood difficulties.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Trauma and PTSD",
                    Description =
                        "Therapeutic support for trauma-related difficulties and post-traumatic stress.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Couples Therapy",
                    Description =
                        "Support for relationship difficulties, communication and conflict resolution.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Child and Adolescent Psychology",
                    Description =
                        "Psychological support for children, adolescents and their families.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Stress and Burnout",
                    Description =
                        "Support for chronic stress, professional burnout and work-life balance.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Grief and Loss",
                    Description =
                        "Support during bereavement, major loss and difficult life transitions.",
                    IsActive = true
                },
                new TherapistSpecialization
                {
                    Name = "Personal Development",
                    Description =
                        "Support for self-confidence, emotional awareness and personal growth.",
                    IsActive = true
                });

            await context.SaveChangesAsync();
        }

        var specializations =
    await context.TherapistSpecializations
        .Where(x => !x.IsDeleted)
        .ToListAsync();

        var therapistsWithoutReference =
            await context.Therapists
                .Where(x =>
                    !x.IsDeleted &&
                    x.SpecializationId == null &&
                    x.Specialization != null &&
                    x.Specialization != string.Empty)
                .ToListAsync();

        foreach (var therapist in therapistsWithoutReference)
        {
            var existingSpecialization =
                specializations.FirstOrDefault(x =>
                    x.Name.ToLower() ==
                    therapist.Specialization.Trim().ToLower());

            if (existingSpecialization == null)
            {
                existingSpecialization =
                    new TherapistSpecialization
                    {
                        Name = therapist.Specialization.Trim(),
                        Description =
                            "Specialization migrated from an existing therapist profile.",
                        IsActive = true
                    };

                context.TherapistSpecializations.Add(
                    existingSpecialization);

                specializations.Add(
                    existingSpecialization);
            }

            therapist.SpecializationReference =
                existingSpecialization;
        }

        if (therapistsWithoutReference.Count > 0)
        {
            await context.SaveChangesAsync();
        }

        if (!await roleManager.RoleExistsAsync(RoleConstants.Admin))
        {
            await roleManager.CreateAsync(
                new IdentityRole<int>(RoleConstants.Admin));
        }

        if (!await roleManager.RoleExistsAsync(RoleConstants.Therapist))
        {
            await roleManager.CreateAsync(
                new IdentityRole<int>(RoleConstants.Therapist));
        }

        if (!await roleManager.RoleExistsAsync(RoleConstants.Client))
        {
            await roleManager.CreateAsync(
                new IdentityRole<int>(RoleConstants.Client));
        }


        var adminUser = new ApplicationUser
        {
            UserName = "desktop",
            Email = "desktop@mindbloom.com",
            FirstName = "System",
            LastName = "Administrator",
            EmailConfirmed = true
        };

        var existingAdmin =
            await userManager.FindByNameAsync(adminUser.UserName);

        if (existingAdmin == null)
        {
            var result = await userManager.CreateAsync(
                adminUser,
                "test");

            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(
                    adminUser,
                    RoleConstants.Admin);
            }
        }

        var mobileUser = new ApplicationUser
        {
            UserName = "mobile",
            Email = "mobile@mindbloom.com",
            FirstName = "Mobile",
            LastName = "User",
            EmailConfirmed = true
        };

        var existingMobile =
            await userManager.FindByNameAsync("mobile");

        if (existingMobile == null)
        {
            var createResult =
                await userManager.CreateAsync(
                    mobileUser,
                    "test");

            if (createResult.Succeeded)
            {
                await userManager.AddToRoleAsync(
                    mobileUser,
                    RoleConstants.Client);
            }
        }

        var seededAdmin =
    await userManager.FindByNameAsync(
        "desktop");

        if (seededAdmin != null &&
            !await context.Articles.AnyAsync())
        {
            var articles =
                new List<Article>
                {
            new()
            {
                Title =
                    "Understanding Anxiety",
                Description =
                    "Learn how anxiety affects thoughts, emotions and everyday behavior.",
                Content =
                    "Anxiety is a natural response to stress, but it can become difficult when it begins to interfere with everyday life. Recognizing triggers, observing physical symptoms and learning healthy coping strategies can help a person regain a sense of control.",
                ImageUrl =
                    "https://images.unsplash.com/photo-1499209974431-9dddcece7f88",
                AuthorUserId =
                    seededAdmin.Id,
                TherapistId = null,
                IsPublished = true,
                PublishedAtUtc =
                    DateTime.UtcNow.AddDays(-5)
            },
            new()
            {
                Title =
                    "Creating a Healthy Sleep Routine",
                Description =
                    "Simple habits that can improve sleep quality and emotional wellbeing.",
                Content =
                    "A regular sleep schedule supports mental and physical health. Try going to bed at a similar time each evening, reduce screen exposure before sleep and create a calm environment that helps your body prepare for rest.",
                ImageUrl =
                    "https://images.unsplash.com/photo-1455642305367-68834a2d5f7a",
                AuthorUserId =
                    seededAdmin.Id,
                TherapistId = null,
                IsPublished = true,
                PublishedAtUtc =
                    DateTime.UtcNow.AddDays(-3)
            },
            new()
            {
                Title =
                    "The Importance of Emotional Awareness",
                Description =
                    "Understanding emotions is an important step toward healthier coping.",
                Content =
                    "Emotional awareness means noticing and naming what you feel without immediately judging yourself. Keeping a journal, tracking your mood and speaking with a therapist can make emotional patterns easier to understand.",
                ImageUrl =
                    "https://images.unsplash.com/photo-1506126613408-eca07ce68773",
                AuthorUserId =
                    seededAdmin.Id,
                TherapistId = null,
                IsPublished = true,
                PublishedAtUtc =
                    DateTime.UtcNow.AddDays(-1)
            }
                };

            context.Articles.AddRange(
                articles);

            await context.SaveChangesAsync();
        }

        var workshopAdmin =
    await userManager.FindByNameAsync(
        "desktop");

        if (workshopAdmin != null &&
            !await context.Workshops.AnyAsync())
        {
            context.Workshops.AddRange(
                new Workshop
                {
                    Title =
                        "Managing Everyday Anxiety",
                    Description =
                        "An interactive workshop focused on recognizing anxiety triggers and learning practical coping strategies.",
                    StartUtc =
                        DateTime.UtcNow.AddDays(14)
                            .Date
                            .AddHours(17),
                    EndUtc =
                        DateTime.UtcNow.AddDays(14)
                            .Date
                            .AddHours(19),
                    Type =
                        WorkshopType.Online,
                    OnlineLink =
                        "https://meet.google.com/example-anxiety",
                    Location = null,
                    Capacity = 30,
                    Price = 20,
                    Status =
                        WorkshopStatus.Scheduled,
                    OrganizerUserId =
                        workshopAdmin.Id
                },
                new Workshop
                {
                    Title =
                        "Emotional Awareness Workshop",
                    Description =
                        "A practical in-person workshop about identifying, understanding and expressing emotions in a healthy way.",
                    StartUtc =
                        DateTime.UtcNow.AddDays(21)
                            .Date
                            .AddHours(16),
                    EndUtc =
                        DateTime.UtcNow.AddDays(21)
                            .Date
                            .AddHours(18),
                    Type =
                        WorkshopType.InPerson,
                    OnlineLink = null,
                    Location =
                        "MindBloom Center, Sarajevo",
                    Capacity = 20,
                    Price = 25,
                    Status =
                        WorkshopStatus.Scheduled,
                    OrganizerUserId =
                        workshopAdmin.Id
                });

            await context.SaveChangesAsync();
        }
    } 
}