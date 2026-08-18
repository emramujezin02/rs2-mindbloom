using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;

namespace MindBloom.Infrastructure.Persistence.Seed;

public static class ApplicationDbSeeder
{
    private const string DemoPassword =
    "MindBloom123!";
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


        var adminUser =
            new ApplicationUser
            {
                UserName =
                    "desktop",

                Email =
                    "desktop@mindbloom.com",

                FirstName =
                    "System",

                LastName =
                    "Administrator",

                DateOfBirth =
                    new DateTime(
                        1990,
                        1,
                        1),

                Gender =
                    "Other",

                EmailConfirmed =
                    true,

                IsEmailVerified =
                    true,

                IsActive =
                    true,

                IsBlocked =
                    false,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        var existingAdmin =
            await userManager.FindByNameAsync(adminUser.UserName);

        if (existingAdmin == null)
        {
            var result =
                await userManager.CreateAsync(
                    adminUser,
                    DemoPassword);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    "Could not create demonstration "
                    + "Admin user: "
                    + string.Join(
                        "; ",
                        result.Errors.Select(
                            error =>
                                error.Description)));
            }
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(
                    adminUser,
                    RoleConstants.Admin);
            }
        }

        var mobileUser =
            new ApplicationUser
            {
                UserName =
                    "mobile",

                Email =
                    "mobile@mindbloom.com",

                FirstName =
                    "Lejla",

                LastName =
                    "Hadžić",

                DateOfBirth =
                    new DateTime(
                        1998,
                        5,
                        14),

                Gender =
                    "Female",

                EmailConfirmed =
                    true,

                IsEmailVerified =
                    true,

                IsActive =
                    true,

                IsBlocked =
                    false,

                CreatedAtUtc =
                    DateTime.UtcNow
            };



        var existingMobile =
            await userManager.FindByNameAsync(
                "mobile");

        if (existingMobile == null)
        {
            var createResult =
                await userManager.CreateAsync(
                    mobileUser,
                    DemoPassword);

            if (!createResult.Succeeded)
            {
                throw new InvalidOperationException(
                    "Could not create demonstration "
                    + "Client user: "
                    + string.Join(
                        "; ",
                        createResult.Errors.Select(
                            error =>
                                error.Description)));
            }

            await userManager.AddToRoleAsync(
                mobileUser,
                RoleConstants.Client);
        }

        var seededClientUser =
            await userManager.FindByNameAsync(
                "mobile");

        if (seededClientUser == null)
        {
            throw new InvalidOperationException(
                "Demonstration Client user "
                + "could not be resolved after seeding.");
        }

        var seededClient =
            await context.Clients
                .FirstOrDefaultAsync(
                    client =>
                        client.UserId ==
                        seededClientUser.Id);

        if (seededClient == null)
        {
            seededClient =
                new Client
                {
                    UserId =
                        seededClientUser.Id,

                    Location =
                        "Sarajevo, Bosnia and Herzegovina",

                    PreferredTherapistGender =
                        "Female",

                    PreferredSessionType =
                        "Online",

                    MinimumPricePerSession =
                        30m,

                    MaximumPricePerSession =
                        80m,

                    PreferredLanguages =
                        "Bosnian, English",

                    AssessmentFocusAreas =
                        "Anxiety, stress, sleep",

                    PreferredDays =
                        "Monday, Wednesday, Friday",

                    HasCompletedOnboarding =
                        true,

                    OnboardingCompletedAtUtc =
                        DateTime.UtcNow
                            .AddDays(-20)
                };

            context.Clients.Add(
                seededClient);

            await context.SaveChangesAsync();
        }

        var therapyApproachSeeds =
    new[]
    {
        new
        {
            Name =
                "Cognitive Behavioral Therapy",

            Description =
                "Evidence-based therapy focused "
                + "on identifying and changing "
                + "unhelpful thought and "
                + "behavior patterns."
        },

        new
        {
            Name =
                "Gestalt Therapy",

            Description =
                "Therapeutic approach focused "
                + "on present-moment awareness, "
                + "personal responsibility and "
                + "emotional experience."
        },

        new
        {
            Name =
                "Person-Centered Therapy",

            Description =
                "Supportive therapeutic approach "
                + "based on empathy, authenticity "
                + "and unconditional positive regard."
        },

        new
        {
            Name =
                "Acceptance and Commitment Therapy",

            Description =
                "Approach focused on acceptance, "
                + "psychological flexibility and "
                + "living according to personal values."
        }
    };

        foreach (var approachSeed
                 in therapyApproachSeeds)
        {
            var exists =
                await context.TherapyApproaches
                    .AnyAsync(
                        approach =>
                            approach.Name ==
                            approachSeed.Name);

            if (!exists)
            {
                context.TherapyApproaches.Add(
                    new TherapyApproach
                    {
                        Name =
                            approachSeed.Name,

                        Description =
                            approachSeed.Description,

                        IsActive =
                            true
                    });
            }
        }

        await context.SaveChangesAsync();



        var approvedTherapistUser =
    await userManager
        .FindByEmailAsync(
            "amina@mindbloom.com");

        if (approvedTherapistUser == null)
        {
            approvedTherapistUser =
                new ApplicationUser
                {
                    UserName =
                        "therapist.amina",

                    Email =
                        "amina@mindbloom.com",

                    FirstName =
                        "Amina",

                    LastName =
                        "Kovačević",

                    DateOfBirth =
                        new DateTime(
                            1988,
                            4,
                            12),

                    Gender =
                        "Female",

                    ProfileImageUrl =
                        "https://images.unsplash.com/photo-1559839734-2b71ea197ec2",

                    EmailConfirmed =
                        true,

                    IsEmailVerified =
                        true,

                    IsActive =
                        true,

                    IsBlocked =
                        false,

                    CreatedAtUtc =
                        DateTime.UtcNow
                            .AddMonths(-8)
                };

            var result =
                await userManager.CreateAsync(
                    approvedTherapistUser,
                    DemoPassword);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    "Could not create approved "
                    + "demonstration Therapist user: "
                    + string.Join(
                        "; ",
                        result.Errors.Select(
                            error =>
                                error.Description)));
            }
        }

        if (!await userManager
                .IsInRoleAsync(
                    approvedTherapistUser,
                    RoleConstants.Therapist))
        {
            await userManager.AddToRoleAsync(
                approvedTherapistUser,
                RoleConstants.Therapist);
        }

        var pendingTherapistUser =
    await userManager
        .FindByEmailAsync(
            "haris@mindbloom.com");

        if (pendingTherapistUser == null)
        {
            pendingTherapistUser =
                new ApplicationUser
                {
                    UserName =
                        "therapist.haris",

                    Email =
                        "haris@mindbloom.com",

                    FirstName =
                        "Haris",

                    LastName =
                        "Selimović",

                    DateOfBirth =
                        new DateTime(
                            1991,
                            9,
                            23),

                    Gender =
                        "Male",

                    ProfileImageUrl =
                        "https://images.unsplash.com/photo-1612349317150-e413f6a5b16d",

                    EmailConfirmed =
                        true,

                    IsEmailVerified =
                        true,

                    IsActive =
                        true,

                    IsBlocked =
                        false,

                    CreatedAtUtc =
                        DateTime.UtcNow
                            .AddDays(-15)
                };

            var result =
                await userManager.CreateAsync(
                    pendingTherapistUser,
                    DemoPassword);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    "Could not create pending "
                    + "demonstration Therapist user: "
                    + string.Join(
                        "; ",
                        result.Errors.Select(
                            error =>
                                error.Description)));
            }
        }

        if (!await userManager
                .IsInRoleAsync(
                    pendingTherapistUser,
                    RoleConstants.Therapist))
        {
            await userManager.AddToRoleAsync(
                pendingTherapistUser,
                RoleConstants.Therapist);
        }

        var anxietySpecialization =
    await context
        .TherapistSpecializations
        .FirstAsync(
            specialization =>
                specialization.Name ==
                "Anxiety Disorders");

        var stressSpecialization =
            await context
                .TherapistSpecializations
                .FirstAsync(
                    specialization =>
                        specialization.Name ==
                        "Stress and Burnout");

        var approvedTherapist =
    await context.Therapists
        .FirstOrDefaultAsync(
            therapist =>
                therapist.UserId ==
                approvedTherapistUser.Id);

        if (approvedTherapist == null)
        {
            approvedTherapist =
                new Therapist
                {
                    UserId =
                        approvedTherapistUser.Id,

                    Biography =
                        "Licensed psychotherapist with "
                        + "extensive experience in anxiety, "
                        + "stress management and personal "
                        + "development.",

                    Specialization =
                        anxietySpecialization.Name,

                    SpecializationId =
                        anxietySpecialization.Id,

                    PricePerSession =
                        55m,

                    HourlyRate =
                        55m,

                    ExperienceYears =
                        9,

                    VerificationStatus =
                        TherapistVerificationStatus.Approved,

                    VerificationNotes =
                        "Professional documentation "
                        + "verified successfully.",

                    ProfileImagePath =
                        approvedTherapistUser
                            .ProfileImageUrl,

                    Location =
                        "Sarajevo",

                    Country =
                        "Bosnia and Herzegovina",

                    City =
                        "Sarajevo",

                    Address =
                        "Zmaja od Bosne 12",

                    Latitude =
                        43.8563,

                    Longitude =
                        18.4131,

                    OffersOnline =
                        true,

                    OffersInPerson =
                        true,

                    Languages =
                        "Bosnian, English",

                    Education =
                        "MA in Psychology, "
                        + "University of Sarajevo"
                };

            context.Therapists.Add(
                approvedTherapist);

            await context.SaveChangesAsync();
        }

        var pendingTherapist =
    await context.Therapists
        .FirstOrDefaultAsync(
            therapist =>
                therapist.UserId ==
                pendingTherapistUser.Id);

        if (pendingTherapist == null)
        {
            pendingTherapist =
                new Therapist
                {
                    UserId =
                        pendingTherapistUser.Id,

                    Biography =
                        "Psychotherapist focused on "
                        + "stress management, burnout "
                        + "prevention and emotional wellbeing.",

                    Specialization =
                        stressSpecialization.Name,

                    SpecializationId =
                        stressSpecialization.Id,

                    PricePerSession =
                        45m,

                    HourlyRate =
                        45m,

                    ExperienceYears =
                        4,

                    VerificationStatus =
                        TherapistVerificationStatus.Pending,

                    VerificationNotes =
                        "Verification documentation "
                        + "is awaiting administrator review.",

                    ProfileImagePath =
                        pendingTherapistUser
                            .ProfileImageUrl,

                    Location =
                        "Mostar",

                    Country =
                        "Bosnia and Herzegovina",

                    City =
                        "Mostar",

                    Address =
                        "Kneza Mihajla Viševića 5",

                    Latitude =
                        43.3438,

                    Longitude =
                        17.8078,

                    OffersOnline =
                        true,

                    OffersInPerson =
                        true,

                    Languages =
                        "Bosnian, English, German",

                    Education =
                        "MA in Psychology, "
                        + "University of Mostar"
                };

            context.Therapists.Add(
                pendingTherapist);

            await context.SaveChangesAsync();
        }

        var cognitiveBehavioral =
    await context.TherapyApproaches
        .FirstAsync(
            approach =>
                approach.Name ==
                "Cognitive Behavioral Therapy");

        var personCentered =
            await context.TherapyApproaches
                .FirstAsync(
                    approach =>
                        approach.Name ==
                        "Person-Centered Therapy");

        var acceptanceCommitment =
            await context.TherapyApproaches
                .FirstAsync(
                    approach =>
                        approach.Name ==
                        "Acceptance and Commitment Therapy");

        if (!await context
        .TherapistTherapyApproaches
        .AnyAsync(
            link =>
                link.TherapistId ==
                    approvedTherapist.Id &&
                link.TherapyApproachId ==
                    cognitiveBehavioral.Id))
        {
            context
                .TherapistTherapyApproaches
                .Add(
                    new TherapistTherapyApproach
                    {
                        TherapistId =
                            approvedTherapist.Id,

                        TherapyApproachId =
                            cognitiveBehavioral.Id
                    });
        }

        if (!await context
                .TherapistTherapyApproaches
                .AnyAsync(
                    link =>
                        link.TherapistId ==
                            approvedTherapist.Id &&
                        link.TherapyApproachId ==
                            personCentered.Id))
        {
            context
                .TherapistTherapyApproaches
                .Add(
                    new TherapistTherapyApproach
                    {
                        TherapistId =
                            approvedTherapist.Id,

                        TherapyApproachId =
                            personCentered.Id
                    });
        }

        if (!await context
        .TherapistTherapyApproaches
        .AnyAsync(
            link =>
                link.TherapistId ==
                    pendingTherapist.Id &&
                link.TherapyApproachId ==
                    acceptanceCommitment.Id))
        {
            context
                .TherapistTherapyApproaches
                .Add(
                    new TherapistTherapyApproach
                    {
                        TherapistId =
                            pendingTherapist.Id,

                        TherapyApproachId =
                            acceptanceCommitment.Id
                    });
        }

        await context.SaveChangesAsync();


        var approvedAvailabilitySeeds =
    new[]
    {
        new
        {
            Day =
                DayOfWeek.Monday,
            Start =
                new TimeSpan(
                    9,
                    0,
                    0),
            End =
                new TimeSpan(
                    13,
                    0,
                    0)
        },

        new
        {
            Day =
                DayOfWeek.Wednesday,
            Start =
                new TimeSpan(
                    14,
                    0,
                    0),
            End =
                new TimeSpan(
                    18,
                    0,
                    0)
        },

        new
        {
            Day =
                DayOfWeek.Friday,
            Start =
                new TimeSpan(
                    10,
                    0,
                    0),
            End =
                new TimeSpan(
                    14,
                    0,
                    0)
        }
    };

        foreach (var availability
                 in approvedAvailabilitySeeds)
        {
            var exists =
                await context
                    .TherapistAvailabilities
                    .AnyAsync(
                        item =>
                            item.TherapistId ==
                                approvedTherapist.Id &&
                            item.DayOfWeek ==
                                availability.Day &&
                            item.StartTime ==
                                availability.Start &&
                            item.EndTime ==
                                availability.End);

            if (!exists)
            {
                context
                    .TherapistAvailabilities
                    .Add(
                        new TherapistAvailability
                        {
                            TherapistId =
                                approvedTherapist.Id,

                            DayOfWeek =
                                availability.Day,

                            StartTime =
                                availability.Start,

                            EndTime =
                                availability.End
                        });
            }
        }

        var pendingAvailabilitySeeds =
    new[]
    {
        new
        {
            Day =
                DayOfWeek.Tuesday,
            Start =
                new TimeSpan(
                    12,
                    0,
                    0),
            End =
                new TimeSpan(
                    16,
                    0,
                    0)
        },

        new
        {
            Day =
                DayOfWeek.Thursday,
            Start =
                new TimeSpan(
                    15,
                    0,
                    0),
            End =
                new TimeSpan(
                    19,
                    0,
                    0)
        }
    };

        foreach (var availability
                 in pendingAvailabilitySeeds)
        {
            var exists =
                await context
                    .TherapistAvailabilities
                    .AnyAsync(
                        item =>
                            item.TherapistId ==
                                pendingTherapist.Id &&
                            item.DayOfWeek ==
                                availability.Day &&
                            item.StartTime ==
                                availability.Start &&
                            item.EndTime ==
                                availability.End);

            if (!exists)
            {
                context
                    .TherapistAvailabilities
                    .Add(
                        new TherapistAvailability
                        {
                            TherapistId =
                                pendingTherapist.Id,

                            DayOfWeek =
                                availability.Day,

                            StartTime =
                                availability.Start,

                            EndTime =
                                availability.End
                        });
            }
        }

        await context.SaveChangesAsync();

        var todayUtc =
    DateTime.UtcNow.Date;

        var completedAppointmentStart =
            todayUtc
                .AddDays(-14)
                .AddHours(10);

        var acceptedAppointmentStart =
            todayUtc
                .AddDays(3)
                .AddHours(14);

        var pendingAppointmentStart =
            todayUtc
                .AddDays(5)
                .AddHours(11);

        var cancelledAppointmentStart =
            todayUtc
                .AddDays(-7)
                .AddHours(15);

        var rejectedAppointmentStart =
            todayUtc
                .AddDays(-5)
                .AddHours(12);

        var completedAppointment =
            await context.Appointments
                .FirstOrDefaultAsync(
                    appointment =>
                        appointment.ClientId ==
                            seededClient.Id &&
                        appointment.TherapistId ==
                            approvedTherapist.Id &&
                        appointment.Notes ==
                            "Demonstration completed therapy appointment.");

        if (completedAppointment == null)
        {
            completedAppointment =
                new Appointment
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentDateUtc =
                        completedAppointmentStart,

                    StartUtc =
                        completedAppointmentStart,

                    EndUtc =
                        completedAppointmentStart
                            .AddHours(1),

                    Status =
                        AppointmentStatus.Completed,

                    Notes =
                        "Demonstration completed "
                        + "therapy appointment.",

                    Price =
                        55m,

                    IsPaid =
                        true,

                    Type =
                        AppointmentType.Online,

                    MeetingLink =
                        "https://meet.example.com/"
                        + "mindbloom-demo-completed",

                    ReminderSent =
                        true
                };

            context.Appointments.Add(
                completedAppointment);

            await context.SaveChangesAsync();
        }

        var acceptedAppointment =
            await context.Appointments
                .FirstOrDefaultAsync(
                    appointment =>
                        appointment.ClientId ==
                            seededClient.Id &&
                        appointment.TherapistId ==
                            approvedTherapist.Id &&
                        appointment.Notes ==
                            "Upcoming confirmed demonstration appointment.");

        if (acceptedAppointment == null)
        {
            acceptedAppointment =
                new Appointment
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentDateUtc =
                        acceptedAppointmentStart,

                    StartUtc =
                        acceptedAppointmentStart,

                    EndUtc =
                        acceptedAppointmentStart
                            .AddHours(1),

                    Status =
                        AppointmentStatus.Accepted,

                    Notes =
                        "Upcoming confirmed "
                        + "demonstration appointment.",

                    Price =
                        55m,

                    IsPaid =
                        true,

                    Type =
                        AppointmentType.Online,

                    MeetingLink =
                        "https://meet.example.com/"
                        + "mindbloom-demo-upcoming",

                    ReminderSent =
                        false
                };

            context.Appointments.Add(
                acceptedAppointment);

            await context.SaveChangesAsync();
        }

        var pendingAppointment =
            await context.Appointments
                .FirstOrDefaultAsync(
                    appointment =>
                        appointment.ClientId ==
                            seededClient.Id &&
                        appointment.TherapistId ==
                            approvedTherapist.Id &&
                        appointment.Notes ==
                            "Demonstration appointment awaiting therapist approval.");

        if (pendingAppointment == null)
        {
            pendingAppointment =
                new Appointment
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentDateUtc =
                        pendingAppointmentStart,

                    StartUtc =
                        pendingAppointmentStart,

                    EndUtc =
                        pendingAppointmentStart
                            .AddHours(1),

                    Status =
                        AppointmentStatus.Pending,

                    Notes =
                        "Demonstration appointment "
                        + "awaiting therapist approval.",

                    Price =
                        55m,

                    IsPaid =
                        false,

                    Type =
                        AppointmentType.Online,

                    ReminderSent =
                        false
                };

            context.Appointments.Add(
                pendingAppointment);

            await context.SaveChangesAsync();
        }

        var cancelledAppointment =
            await context.Appointments
                .FirstOrDefaultAsync(
                    appointment =>
                        appointment.ClientId ==
                            seededClient.Id &&
                        appointment.TherapistId ==
                            approvedTherapist.Id &&
                        appointment.Notes ==
                            "Demonstration appointment cancelled by the client.");

        if (cancelledAppointment == null)
        {
            cancelledAppointment =
                new Appointment
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentDateUtc =
                        cancelledAppointmentStart,

                    StartUtc =
                        cancelledAppointmentStart,

                    EndUtc =
                        cancelledAppointmentStart
                            .AddHours(1),

                    Status =
                        AppointmentStatus.Cancelled,

                    Notes =
                        "Demonstration appointment "
                        + "cancelled by the client.",

                    Price =
                        55m,

                    IsPaid =
                        false,

                    Type =
                        AppointmentType.InPerson,

                    Location =
                        "Zmaja od Bosne 12, Sarajevo",

                    ReminderSent =
                        false
                };

            context.Appointments.Add(
                cancelledAppointment);

            await context.SaveChangesAsync();
        }

        var rejectedAppointment =
            await context.Appointments
                .FirstOrDefaultAsync(
                    appointment =>
                        appointment.ClientId ==
                            seededClient.Id &&
                        appointment.TherapistId ==
                            approvedTherapist.Id &&
                        appointment.Notes ==
                            "Demonstration appointment rejected because the requested time was unavailable.");

        if (rejectedAppointment == null)
        {
            rejectedAppointment =
                new Appointment
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentDateUtc =
                        rejectedAppointmentStart,

                    StartUtc =
                        rejectedAppointmentStart,

                    EndUtc =
                        rejectedAppointmentStart
                            .AddHours(1),

                    Status =
                        AppointmentStatus.Rejected,

                    Notes =
                        "Demonstration appointment "
                        + "rejected because the requested "
                        + "time was unavailable.",

                    Price =
                        55m,

                    IsPaid =
                        false,

                    Type =
                        AppointmentType.Online,

                    ReminderSent =
                        false
                };

            context.Appointments.Add(
                rejectedAppointment);

            await context.SaveChangesAsync();
        }

        var completedPayment =
    await context.Payments
        .FirstOrDefaultAsync(
            payment =>
                payment.AppointmentId ==
                    completedAppointment.Id);

        if (completedPayment == null)
        {
            context.Payments.Add(
                new Payment
                {
                    AppointmentId =
                        completedAppointment.Id,

                    Amount =
                        completedAppointment.Price,

                    Status =
                        PaymentStatus.Paid,

                    StripePaymentIntentId =
                        "pi_demo_completed_001",

                    PaidAtUtc =
                        completedAppointment.StartUtc
                            .AddDays(-2)
                });

            await context.SaveChangesAsync();
        }

        var acceptedPayment =
    await context.Payments
        .FirstOrDefaultAsync(
            payment =>
                payment.AppointmentId ==
                    acceptedAppointment.Id);

        if (acceptedPayment == null)
        {
            context.Payments.Add(
                new Payment
                {
                    AppointmentId =
                        acceptedAppointment.Id,

                    Amount =
                        acceptedAppointment.Price,

                    Status =
                        PaymentStatus.Paid,

                    StripePaymentIntentId =
                        "pi_demo_upcoming_001",

                    PaidAtUtc =
                        DateTime.UtcNow
                            .AddDays(-1)
                });

            await context.SaveChangesAsync();
        }


        var approvedReview =
    await context.Reviews
        .FirstOrDefaultAsync(
            review =>
                review.AppointmentId ==
                    completedAppointment.Id);

        if (approvedReview == null)
        {
            approvedReview =
                new Review
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentId =
                        completedAppointment.Id,

                    Rating =
                        5,

                    Comment =
                        "The session was very helpful. "
                        + "The therapist was professional, "
                        + "understanding and supportive.",

                    IsApproved =
                        true,

                    ModerationStatus =
                        ReviewModerationStatus.Approved,

                    ModeratedByUserId =
                        (existingAdmin ?? adminUser).Id,

                    ModeratedAtUtc =
                        DateTime.UtcNow
                            .AddDays(-10),

                    ModerationReason =
                        "Review approved for "
                        + "demonstration purposes.",

                    TherapistReply =
                        "Thank you for your feedback. "
                        + "I am glad the session "
                        + "was helpful.",

                    TherapistReplyCreatedAtUtc =
                        DateTime.UtcNow
                            .AddDays(-9)
                };

            context.Reviews.Add(
                approvedReview);

            await context.SaveChangesAsync();
        }

        var secondCompletedStart =
    todayUtc
        .AddDays(-30)
        .AddHours(13);

        var secondCompletedAppointment =
            await context.Appointments
                .FirstOrDefaultAsync(
                    appointment =>
                        appointment.ClientId ==
                            seededClient.Id &&
                        appointment.TherapistId ==
                            approvedTherapist.Id &&
                        appointment.Notes ==
                            "Completed appointment used for pending review demonstration.");

        if (secondCompletedAppointment == null)
        {
            secondCompletedAppointment =
                new Appointment
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentDateUtc =
                        secondCompletedStart,

                    StartUtc =
                        secondCompletedStart,

                    EndUtc =
                        secondCompletedStart
                            .AddHours(1),

                    Status =
                        AppointmentStatus.Completed,

                    Notes =
                        "Completed appointment used "
                        + "for pending review "
                        + "demonstration.",

                    Price =
                        55m,

                    IsPaid =
                        true,

                    Type =
                        AppointmentType.Online,

                    MeetingLink =
                        "https://meet.example.com/"
                        + "mindbloom-demo-review",

                    ReminderSent =
                        true
                };

            context.Appointments.Add(
                secondCompletedAppointment);

            await context.SaveChangesAsync();
        }

        if (!await context.Payments
        .AnyAsync(
            payment =>
                payment.AppointmentId ==
                    secondCompletedAppointment.Id))
        {
            context.Payments.Add(
                new Payment
                {
                    AppointmentId =
                        secondCompletedAppointment.Id,

                    Amount =
                        secondCompletedAppointment.Price,

                    Status =
                        PaymentStatus.Paid,

                    StripePaymentIntentId =
                        "pi_demo_review_001",

                    PaidAtUtc =
                        secondCompletedAppointment
                            .StartUtc
                            .AddDays(-1)
                });

            await context.SaveChangesAsync();
        }


        var pendingReviewExists =
    await context.Reviews
        .AnyAsync(
            review =>
                review.AppointmentId ==
                    secondCompletedAppointment.Id);

        if (!pendingReviewExists)
        {
            context.Reviews.Add(
                new Review
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    AppointmentId =
                        secondCompletedAppointment.Id,

                    Rating =
                        4,

                    Comment =
                        "The session was useful and "
                        + "the communication was clear.",

                    IsApproved =
                        false,

                    ModerationStatus =
                        ReviewModerationStatus.Pending,

                    ModeratedByUserId =
                        null,

                    ModeratedAtUtc =
                        null,

                    ModerationReason =
                        null
                });

            await context.SaveChangesAsync();
        }

        var membershipPlanSeeds =
    new[]
    {
        new MembershipPlan
        {
            Name =
                "MindBloom 10 Sessions",

            Description =
                "Ten therapy sessions for clients "
                + "who want a flexible introduction "
                + "to ongoing psychotherapy.",

            PlanType =
                MembershipPlanType.TenSessions,

            Price =
                495m,

            DurationMonths =
                4,

            IncludedSessions =
                10,

            DiscountPercentage =
                10m,

            BenefitsJson =
                """
                [
                  "10 therapy sessions",
                  "Priority booking",
                  "Mood and journal tracking"
                ]
                """,

            IsActive =
                true
        },

        new MembershipPlan
        {
            Name =
                "MindBloom 20 Sessions",

            Description =
                "Twenty therapy sessions for longer-term "
                + "therapeutic work and continuity.",

            PlanType =
                MembershipPlanType.TwentySessions,

            Price =
                935m,

            DurationMonths =
                8,

            IncludedSessions =
                20,

            DiscountPercentage =
                15m,

            BenefitsJson =
                """
                [
                  "20 therapy sessions",
                  "Priority booking",
                  "Mood and journal tracking",
                  "Extended therapy continuity"
                ]
                """,

            IsActive =
                true
        },

        new MembershipPlan
        {
            Name =
                "MindBloom 30 Sessions",

            Description =
                "Thirty therapy sessions intended for "
                + "long-term therapeutic support.",

            PlanType =
                MembershipPlanType.ThirtySessions,

            Price =
                1320m,

            DurationMonths =
                12,

            IncludedSessions =
                30,

            DiscountPercentage =
                20m,

            BenefitsJson =
                """
                [
                  "30 therapy sessions",
                  "Priority booking",
                  "Mood and journal tracking",
                  "Long-term therapy continuity"
                ]
                """,

            IsActive =
                true
        }
    };

        foreach (var planSeed
                 in membershipPlanSeeds)
        {
            var existingPlan =
                await context.MembershipPlans
                    .FirstOrDefaultAsync(
                        plan =>
                            plan.PlanType ==
                            planSeed.PlanType);

            if (existingPlan == null)
            {
                context.MembershipPlans.Add(
                    planSeed);
            }
        }

        await context.SaveChangesAsync();

        var tenSessionPlan =
    await context.MembershipPlans
        .FirstAsync(
            plan =>
                plan.PlanType ==
                MembershipPlanType
                    .TenSessions);

        var activeMembership =
            await context.ClientMemberships
                .FirstOrDefaultAsync(
                    membership =>
                        membership.ClientId ==
                            seededClient.Id &&
                        membership.TherapistId ==
                            approvedTherapist.Id &&
                        membership.PlanType ==
                            MembershipPlanType
                                .TenSessions);

        if (activeMembership == null)
        {
            activeMembership =
                new ClientMembership
                {
                    ClientId =
                        seededClient.Id,

                    TherapistId =
                        approvedTherapist.Id,

                    PlanType =
                        MembershipPlanType
                            .TenSessions,

                    TotalSessions =
                        tenSessionPlan
                            .IncludedSessions,

                    RemainingSessions =
                        8,

                    Price =
                        tenSessionPlan.Price,

                    DurationMonths =
                        tenSessionPlan
                            .DurationMonths,

                    IsActive =
                        true,

                    PurchasedAtUtc =
                        DateTime.UtcNow
                            .AddDays(-25),

                    ExpiresAtUtc =
                        DateTime.UtcNow
                            .AddMonths(
                                tenSessionPlan
                                    .DurationMonths)
                };

            context.ClientMemberships.Add(
                activeMembership);

            await context.SaveChangesAsync();
        }

        var membershipPayment =
    await context.MembershipPayments
        .FirstOrDefaultAsync(
            payment =>
                payment.ClientMembershipId ==
                    activeMembership.Id);

        if (membershipPayment == null)
        {
            membershipPayment =
                new MembershipPayment
                {
                    ClientMembershipId =
                        activeMembership.Id,

                    Amount =
                        activeMembership.Price,

                    Currency =
                        "usd",

                    Status =
                        PaymentStatus.Paid,

                    StripePaymentIntentId =
                        "pi_demo_membership_001",

                    PaidAtUtc =
                        activeMembership
                            .PurchasedAtUtc
                };

            context.MembershipPayments.Add(
                membershipPayment);

            await context.SaveChangesAsync();
        }

        var completedMembershipUsage =
    await context.MembershipUsages
        .FirstOrDefaultAsync(
            usage =>
                usage.ClientMembershipId ==
                    activeMembership.Id &&
                usage.AppointmentId ==
                    completedAppointment.Id);

        if (completedMembershipUsage == null)
        {
            context.MembershipUsages.Add(
                new MembershipUsage
                {
                    ClientMembershipId =
                        activeMembership.Id,

                    AppointmentId =
                        completedAppointment.Id,

                    UsedAtUtc =
                        completedAppointment
                            .EndUtc,

                    Status =
                        MembershipUsageStatus
                            .Consumed,

                    ReservedAtUtc =
                        completedAppointment
                            .StartUtc
                            .AddDays(-3),

                    ConsumedAtUtc =
                        completedAppointment
                            .EndUtc,

                    RestoredAtUtc =
                        null,

                    ResolutionReason =
                        "Session completed successfully."
                });

            await context.SaveChangesAsync();
        }

        var reservedMembershipUsage =
    await context.MembershipUsages
        .FirstOrDefaultAsync(
            usage =>
                usage.ClientMembershipId ==
                    activeMembership.Id &&
                usage.AppointmentId ==
                    acceptedAppointment.Id);

        if (reservedMembershipUsage == null)
        {
            context.MembershipUsages.Add(
                new MembershipUsage
                {
                    ClientMembershipId =
                        activeMembership.Id,

                    AppointmentId =
                        acceptedAppointment.Id,

                    UsedAtUtc =
                        DateTime.UtcNow,

                    Status =
                        MembershipUsageStatus
                            .Reserved,

                    ReservedAtUtc =
                        DateTime.UtcNow
                            .AddDays(-1),

                    ConsumedAtUtc =
                        null,

                    RestoredAtUtc =
                        null,

                    ResolutionReason =
                        "Session reserved from active membership."
                });

            await context.SaveChangesAsync();
        }

        var moodEntryOne =
    await context.MoodEntries
        .FirstOrDefaultAsync(
            mood =>
                mood.ClientId ==
                    seededClient.Id &&
                mood.Notes ==
                    "Demo mood entry - calm morning.");

        if (moodEntryOne == null)
        {
            moodEntryOne =
                new MoodEntry
                {
                    ClientId =
                        seededClient.Id,

                    MoodScore =
                        8,

                    Emotion =
                        "Calm",

                    Notes =
                        "Demo mood entry - calm morning."
                };

            context.MoodEntries.Add(
                moodEntryOne);

            await context.SaveChangesAsync();
        }

        var moodEntryTwo =
            await context.MoodEntries
                .FirstOrDefaultAsync(
                    mood =>
                        mood.ClientId ==
                            seededClient.Id &&
                        mood.Notes ==
                            "Demo mood entry - stressful day.");

        if (moodEntryTwo == null)
        {
            moodEntryTwo =
                new MoodEntry
                {
                    ClientId =
                        seededClient.Id,

                    MoodScore =
                        4,

                    Emotion =
                        "Anxious",

                    Notes =
                        "Demo mood entry - stressful day."
                };

            context.MoodEntries.Add(
                moodEntryTwo);

            await context.SaveChangesAsync();
        }

        var moodEntryThree =
            await context.MoodEntries
                .FirstOrDefaultAsync(
                    mood =>
                        mood.ClientId ==
                            seededClient.Id &&
                        mood.Notes ==
                            "Demo mood entry - positive progress.");

        if (moodEntryThree == null)
        {
            moodEntryThree =
                new MoodEntry
                {
                    ClientId =
                        seededClient.Id,

                    MoodScore =
                        9,

                    Emotion =
                        "Hopeful",

                    Notes =
                        "Demo mood entry - positive progress."
                };

            context.MoodEntries.Add(
                moodEntryThree);

            await context.SaveChangesAsync();
        }

        var journalEntry =
    await context.PrivateJournalEntries
        .FirstOrDefaultAsync(
            entry =>
                entry.ClientId ==
                    seededClient.Id &&
                entry.Title ==
                    "A positive step forward");

        if (journalEntry == null)
        {
            journalEntry =
                new PrivateJournalEntry
                {
                    ClientId =
                        seededClient.Id,

                    Title =
                        "A positive step forward",

                    Content =
                        "Today I took some time to reflect "
                        + "on the progress I have made. "
                        + "I want to continue building healthy "
                        + "routines and making time for myself.",

                    EntryDateUtc =
                        DateTime.UtcNow
                            .AddDays(-2),

                    MoodEntryId =
                        moodEntryThree.Id
                };

            context.PrivateJournalEntries.Add(
                journalEntry);

            await context.SaveChangesAsync();
        }

        var appointmentNotification =
            await context.Notifications
                .FirstOrDefaultAsync(
                    notification =>
                        notification.UserId ==
                            seededClient.UserId &&
                        notification.AppointmentId ==
                            acceptedAppointment.Id &&
                        notification.Title ==
                            "Upcoming therapy session");

        if (appointmentNotification == null)
        {
            context.Notifications.Add(
                new Notification
                {
                    UserId =
                        seededClient.UserId,

                    AppointmentId =
                        acceptedAppointment.Id,

                    ActionType =
                        NotificationActionType
                            .Appointment,

                    ResourceId =
                        acceptedAppointment.Id,

                    Title =
                        "Upcoming therapy session",

                    Message =
                        "Your upcoming therapy session "
                        + "has been confirmed.",

                    IsRead =
                        false,

                    SentAtUtc =
                        DateTime.UtcNow
                            .AddHours(-3)
                });

            await context.SaveChangesAsync();
        }

        var membershipNotification =
    await context.Notifications
        .FirstOrDefaultAsync(
            notification =>
                notification.UserId ==
                    seededClient.UserId &&
                notification.ActionType ==
                    NotificationActionType
                        .Membership &&
                notification.Title ==
                    "Membership activated");

        if (membershipNotification == null)
        {
            context.Notifications.Add(
                new Notification
                {
                    UserId =
                        seededClient.UserId,

                    AppointmentId =
                        null,

                    ActionType =
                        NotificationActionType
                            .Membership,

                    ResourceId =
                        activeMembership.Id,

                    Title =
                        "Membership activated",

                    Message =
                        "Your MindBloom 10 Sessions "
                        + "membership is now active.",

                    IsRead =
                        true,

                    SentAtUtc =
                        activeMembership
                            .PurchasedAtUtc
                            ?? DateTime.UtcNow
                                .AddDays(-25)
                });

            await context.SaveChangesAsync();
        }

        var therapistNotification =
    await context.Notifications
        .FirstOrDefaultAsync(
            notification =>
                notification.UserId ==
                    approvedTherapist.UserId &&
                notification.AppointmentId ==
                    pendingAppointment.Id &&
                notification.Title ==
                    "New appointment request");

        if (therapistNotification == null)
        {
            context.Notifications.Add(
                new Notification
                {
                    UserId =
                        approvedTherapist.UserId,

                    AppointmentId =
                        pendingAppointment.Id,

                    ActionType =
                        NotificationActionType
                            .Appointment,

                    ResourceId =
                        pendingAppointment.Id,

                    Title =
                        "New appointment request",

                    Message =
                        "You have received a new "
                        + "appointment request.",

                    IsRead =
                        false,

                    SentAtUtc =
                        DateTime.UtcNow
                            .AddHours(-1)
                });

            await context.SaveChangesAsync();
        }

        var demoConversation =
    await context.Conversations
        .FirstOrDefaultAsync(
            conversation =>
                conversation.AppointmentId ==
                    completedAppointment.Id);

        if (demoConversation == null)
        {
            demoConversation =
                new Conversation
                {
                    AppointmentId =
                        completedAppointment.Id,

                    IsClosed =
                        false,

                    ClosedAtUtc =
                        null
                };

            context.Conversations.Add(
                demoConversation);

            await context.SaveChangesAsync();
        }

        var clientParticipant =
    await context.ConversationParticipants
        .FirstOrDefaultAsync(
            participant =>
                participant.ConversationId ==
                    demoConversation.Id &&
                participant.UserId ==
                    seededClient.UserId);

        if (clientParticipant == null)
        {
            context.ConversationParticipants.Add(
                new ConversationParticipant
                {
                    ConversationId =
                        demoConversation.Id,

                    UserId =
                        seededClient.UserId,

                    JoinedAtUtc =
                        completedAppointment
                            .StartUtc
                            .AddMinutes(-10),

                    LastReadAtUtc =
                        completedAppointment
                            .EndUtc,

                    IsActive =
                        true
                });

            await context.SaveChangesAsync();
        }

        var therapistParticipant =
            await context.ConversationParticipants
                .FirstOrDefaultAsync(
                    participant =>
                        participant.ConversationId ==
                            demoConversation.Id &&
                        participant.UserId ==
                            approvedTherapist.UserId);

        if (therapistParticipant == null)
        {
            context.ConversationParticipants.Add(
                new ConversationParticipant
                {
                    ConversationId =
                        demoConversation.Id,

                    UserId =
                        approvedTherapist.UserId,

                    JoinedAtUtc =
                        completedAppointment
                            .StartUtc
                            .AddMinutes(-10),

                    LastReadAtUtc =
                        completedAppointment
                            .EndUtc,

                    IsActive =
                        true
                });

            await context.SaveChangesAsync();
        }


        var clientChatMessage =
    await context.ChatMessages
        .FirstOrDefaultAsync(
            message =>
                message.ConversationId ==
                    demoConversation.Id &&
                message.ClientMessageId ==
                    "seed-client-message-001");

        if (clientChatMessage == null)
        {
            context.ChatMessages.Add(
                new ChatMessage
                {
                    ConversationId =
                        demoConversation.Id,

                    SenderUserId =
                        seededClient.UserId,

                    Content =
                        "Hello, I am ready for "
                        + "today's session.",

                    SentAtUtc =
                        completedAppointment
                            .StartUtc
                            .AddMinutes(-5),

                    IsEdited =
                        false,

                    EditedAtUtc =
                        null,

                    ClientMessageId =
                        "seed-client-message-001"
                });

            await context.SaveChangesAsync();
        }

        var therapistChatMessage =
    await context.ChatMessages
        .FirstOrDefaultAsync(
            message =>
                message.ConversationId ==
                    demoConversation.Id &&
                message.ClientMessageId ==
                    "seed-therapist-message-001");

        if (therapistChatMessage == null)
        {
            context.ChatMessages.Add(
                new ChatMessage
                {
                    ConversationId =
                        demoConversation.Id,

                    SenderUserId =
                        approvedTherapist.UserId,

                    Content =
                        "Hello! Welcome. We can begin "
                        + "whenever you are ready.",

                    SentAtUtc =
                        completedAppointment
                            .StartUtc
                            .AddMinutes(-4),

                    IsEdited =
                        false,

                    EditedAtUtc =
                        null,

                    ClientMessageId =
                        "seed-therapist-message-001"
                });

            await context.SaveChangesAsync();
        }

        var secondClientChatMessage =
    await context.ChatMessages
        .FirstOrDefaultAsync(
            message =>
                message.ConversationId ==
                    demoConversation.Id &&
                message.ClientMessageId ==
                    "seed-client-message-002");

        if (secondClientChatMessage == null)
        {
            context.ChatMessages.Add(
                new ChatMessage
                {
                    ConversationId =
                        demoConversation.Id,

                    SenderUserId =
                        seededClient.UserId,

                    Content =
                        "Thank you. I would like to "
                        + "talk about managing stress "
                        + "and improving my daily routine.",

                    SentAtUtc =
                        completedAppointment
                            .StartUtc
                            .AddMinutes(-3),

                    IsEdited =
                        false,

                    EditedAtUtc =
                        null,

                    ClientMessageId =
                        "seed-client-message-002"
                });

            await context.SaveChangesAsync();
        }

        var seededAdmin =
    await userManager.FindByNameAsync(
        "desktop");

        if (seededAdmin != null)
        {
            var articleSeeds =
                new[]
                {
            new Article
            {
                Title =
                    "Understanding Anxiety",

                Description =
                    "Learn how anxiety affects thoughts, "
                    + "emotions and everyday behavior.",

                Content =
                    "Anxiety is a natural response to stress, "
                    + "but it can become difficult when it "
                    + "begins to interfere with everyday life. "
                    + "Recognizing triggers, observing physical "
                    + "symptoms and learning healthy coping "
                    + "strategies can help a person regain "
                    + "a sense of control.",

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1499209974431-9dddcece7f88",

                AuthorUserId =
                    seededAdmin.Id,

                TherapistId =
                    null,

                IsPublished =
                    true,

                PublishedAtUtc =
                    DateTime.UtcNow
                        .AddDays(-5)
            },

            new Article
            {
                Title =
                    "Creating a Healthy Sleep Routine",

                Description =
                    "Simple habits that can improve sleep "
                    + "quality and emotional wellbeing.",

                Content =
                    "A regular sleep schedule supports mental "
                    + "and physical health. Try going to bed "
                    + "at a similar time each evening, reduce "
                    + "screen exposure before sleep and create "
                    + "a calm environment that helps your body "
                    + "prepare for rest.",

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1455642305367-68834a2d5f7a",

                AuthorUserId =
                    seededAdmin.Id,

                TherapistId =
                    null,

                IsPublished =
                    true,

                PublishedAtUtc =
                    DateTime.UtcNow
                        .AddDays(-3)
            },

            new Article
            {
                Title =
                    "The Importance of Emotional Awareness",

                Description =
                    "Understanding emotions is an important "
                    + "step toward healthier coping.",

                Content =
                    "Emotional awareness means noticing and "
                    + "naming what you feel without immediately "
                    + "judging yourself. Keeping a journal, "
                    + "tracking your mood and speaking with a "
                    + "therapist can make emotional patterns "
                    + "easier to understand.",

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1506126613408-eca07ce68773",

                AuthorUserId =
                    seededAdmin.Id,

                TherapistId =
                    null,

                IsPublished =
                    true,

                PublishedAtUtc =
                    DateTime.UtcNow
                        .AddDays(-1)
            },

            new Article
            {
                Title =
                    "Five Ways to Manage Everyday Stress",

                Description =
                    "Practical steps that can help reduce "
                    + "daily stress and improve balance.",

                Content =
                    "Small changes can have a meaningful "
                    + "impact on daily stress. Regular breaks, "
                    + "realistic planning, movement, sleep and "
                    + "open communication can support emotional "
                    + "wellbeing and reduce overwhelm.",

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1500530855697-b586d89ba3ee",

                AuthorUserId =
                    approvedTherapistUser.Id,

                TherapistId =
                    approvedTherapist.Id,

                IsPublished =
                    true,

                PublishedAtUtc =
                    DateTime.UtcNow
                        .AddDays(-2)
            }
                };

            foreach (var articleSeed
                     in articleSeeds)
            {
                var exists =
                    await context.Articles
                        .AnyAsync(
                            article =>
                                article.Title ==
                                articleSeed.Title);

                if (!exists)
                {
                    context.Articles.Add(
                        articleSeed);
                }
            }

            await context.SaveChangesAsync();
        }

        var workshopAdmin =
    await userManager.FindByNameAsync(
        "desktop");



        if (workshopAdmin != null)
        {
            var workshopSeeds =
                new[]
                {
            new Workshop
            {
                Title =
                    "Managing Everyday Anxiety",

                Description =
                    "An interactive workshop focused on "
                    + "recognizing anxiety triggers and "
                    + "learning practical coping strategies.",

                StartUtc =
                    DateTime.UtcNow
                        .AddDays(14)
                        .Date
                        .AddHours(17),

                EndUtc =
                    DateTime.UtcNow
                        .AddDays(14)
                        .Date
                        .AddHours(19),

                RegistrationDeadlineUtc =
                    DateTime.UtcNow
                        .AddDays(12)
                        .Date
                        .AddHours(23),

                Type =
                    WorkshopType.Online,

                OnlineLink =
                    "https://meet.example.com/"
                    + "mindbloom-anxiety-workshop",

                Location =
                    null,

                Capacity =
                    30,

                Price =
                    20m,

                Status =
                    WorkshopStatus.Scheduled,

                OrganizerUserId =
                    workshopAdmin.Id,

                TherapistId =
                    approvedTherapist.Id,

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1521737604893-d14cc237f11d"
            },

            new Workshop
            {
                Title =
                    "Emotional Awareness Workshop",

                Description =
                    "A practical in-person workshop about "
                    + "identifying, understanding and expressing "
                    + "emotions in a healthy way.",

                StartUtc =
                    DateTime.UtcNow
                        .AddDays(21)
                        .Date
                        .AddHours(16),

                EndUtc =
                    DateTime.UtcNow
                        .AddDays(21)
                        .Date
                        .AddHours(18),

                RegistrationDeadlineUtc =
                    DateTime.UtcNow
                        .AddDays(19)
                        .Date
                        .AddHours(23),

                Type =
                    WorkshopType.InPerson,

                OnlineLink =
                    null,

                Location =
                    "MindBloom Center, Sarajevo",

                Capacity =
                    20,

                Price =
                    25m,

                Status =
                    WorkshopStatus.Scheduled,

                OrganizerUserId =
                    workshopAdmin.Id,

                TherapistId =
                    approvedTherapist.Id,

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1517245386807-bb43f82c33c4"
            },

            new Workshop
            {
                Title =
                    "Stress Management for Students",

                Description =
                    "Online workshop focused on practical "
                    + "strategies for managing academic "
                    + "pressure and maintaining wellbeing.",

                StartUtc =
                    DateTime.UtcNow
                        .AddDays(28)
                        .Date
                        .AddHours(18),

                EndUtc =
                    DateTime.UtcNow
                        .AddDays(28)
                        .Date
                        .AddHours(20),

                RegistrationDeadlineUtc =
                    DateTime.UtcNow
                        .AddDays(26)
                        .Date
                        .AddHours(23),

                Type =
                    WorkshopType.Online,

                OnlineLink =
                    "https://meet.example.com/"
                    + "mindbloom-student-stress",

                Location =
                    null,

                Capacity =
                    40,

                Price =
                    15m,

                Status =
                    WorkshopStatus.Scheduled,

                OrganizerUserId =
                    workshopAdmin.Id,

                TherapistId =
                    approvedTherapist.Id,

                ImageUrl =
                    "https://images.unsplash.com/"
                    + "photo-1523240795612-9a054b0db644"
            }
                };

            foreach (var workshopSeed
                     in workshopSeeds)
            {
                var exists =
                    await context.Workshops
                        .AnyAsync(
                            workshop =>
                                workshop.Title ==
                                workshopSeed.Title);

                if (!exists)
                {
                    context.Workshops.Add(
                        workshopSeed);
                }
            }

            await context.SaveChangesAsync();
        }
    }
}