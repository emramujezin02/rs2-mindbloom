using System.Net;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.AdminReports.DTOs;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Chat.DTOs;
using MindBloom.Application.Features.ClientOnboarding.DTOs;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class ClientJourneyEndToEndTests
    : IClassFixture<
        MindBloomEndToEndTestFactory>
{
    private readonly
        MindBloomEndToEndTestFactory
        _factory;

    public ClientJourneyEndToEndTests(
        MindBloomEndToEndTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        EndToEndJourney_ClientTherapistAndAdmin_CompletesSuccessfully()
    {
        /*
         * ==================================================
         * ARRANGE
         * ==================================================
         */

        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Client);

        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Therapist);

        await _factory
            .EnsureRoleExistsAsync(
                RoleConstants.Admin);

        var notificationPublisher =
            _factory.Services
                .GetRequiredService<
                    TestNotificationPublisher>();

        notificationPublisher.Reset();

        var integrationPublisher =
            _factory.Services
                .GetRequiredService<
                    TestIntegrationEventPublisher>();

        integrationPublisher.Reset();

        var unique =
            Guid.NewGuid()
                .ToString("N");

        var clientEmail =
            $"client-e2e-{unique}"
            + "@mindbloom.test";

        var clientUsername =
            $"client_e2e_{unique}";

        const string clientPassword =
            "ClientE2EPassword123!";

        var therapistEmail =
            $"therapist-e2e-{unique}"
            + "@mindbloom.test";

        const string therapistPassword =
            "TherapistE2EPassword123!";

        var pendingTherapistEmail =
            $"pending-therapist-e2e-{unique}"
            + "@mindbloom.test";

        const string pendingTherapistPassword =
            "PendingTherapistE2E123!";

        var adminEmail =
            $"admin-e2e-{unique}"
            + "@mindbloom.test";

        const string adminPassword =
            "AdminE2EPassword123!";

        /*
         * Termin držimo dovoljno daleko
         * u budućnosti da test ne zavisi
         * od trenutnog sata.
         */
        var appointmentDate =
            DateTime.UtcNow
                .Date
                .AddDays(7);

        var appointmentStartUtc =
            appointmentDate
                .AddHours(10);

        var appointmentEndUtc =
            appointmentStartUtc
                .AddHours(1);

        /*
         * ==================================================
         * 1. THERAPIST TEST PRECONDITION
         * ==================================================
         */

        var therapistUserId =
            await _factory
                .SeedActiveUserAsync(
                    RoleConstants.Therapist,
                    therapistEmail,
                    therapistPassword);

        var pendingTherapistUserId =
            await _factory
                .SeedActiveUserAsync(
                    RoleConstants.Therapist,
                    pendingTherapistEmail,
                    pendingTherapistPassword);

        var adminUserId =
            await _factory
                .SeedActiveUserAsync(
                    RoleConstants.Admin,
                    adminEmail,
                    adminPassword);

        int therapistId;
        int pendingTherapistId;
        int therapyApproachId;

        using (var scope =
               _factory.Services
                   .CreateScope())
        {
            var context =
                scope.ServiceProvider
                    .GetRequiredService<
                        ApplicationDbContext>();

            var therapist =
                new Therapist
                {
                    UserId =
                        therapistUserId,

                    Biography =
                        "E2E therapist for anxiety "
                        + "and stress support.",

                    Specialization =
                        "Anxiety and stress",

                    PricePerSession =
                        50m,

                    HourlyRate =
                        50m,

                    ExperienceYears =
                        6,

                    VerificationStatus =
                        TherapistVerificationStatus
                            .Approved,

                    Country =
                        "Bosnia and Herzegovina",

                    City =
                        "Mostar",

                    Address =
                        "E2E Test Address",

                    Education =
                        "E2E Therapy Education",

                    OffersOnline =
                        true,

                    OffersInPerson =
                        false,

                    Languages =
                        "English"
                };

            var pendingTherapist =
                new Therapist
                {
                    UserId =
                        pendingTherapistUserId,

                    Biography =
                        "E2E pending therapist awaiting "
                        + "administrator verification.",

                    Specialization =
                        "Stress management",

                    PricePerSession =
                        45m,

                    HourlyRate =
                        45m,

                    ExperienceYears =
                        4,

                    VerificationStatus =
                        TherapistVerificationStatus
                            .Pending,

                    Country =
                        "Bosnia and Herzegovina",

                    City =
                        "Mostar",

                    Address =
                        "Pending E2E Test Address",

                    Education =
                        "Pending E2E Therapy Education",

                    OffersOnline =
                        true,

                    OffersInPerson =
                        false,

                    Languages =
                        "English"
                };

            var therapyApproach =
                new TherapyApproach
                {
                    Name =
                        $"Cognitive Behavioral Therapy "
                        + $"{unique}",

                    Description =
                        "E2E therapy approach.",

                    IsActive =
                        true
                };

            context.Therapists.Add(
                therapist);

            context.Therapists.Add(
                pendingTherapist);

            context.TherapyApproaches.Add(
                therapyApproach);

            await context
                .SaveChangesAsync();

            therapistId =
                therapist.Id;

            pendingTherapistId =
                pendingTherapist.Id;

            therapyApproachId =
                therapyApproach.Id;

            context
                .TherapistTherapyApproaches
                .Add(
                    new TherapistTherapyApproach
                    {
                        TherapistId =
                            therapistId,

                        TherapyApproachId =
                            therapyApproachId
                    });

            context.TherapistDocuments.Add(
                new TherapistDocument
                {
                    TherapistId =
                        pendingTherapistId,

                    FileName =
                        "e2e-verification-document.pdf",

                    FilePath =
                        "e2e/verification/"
                        + $"{unique}.pdf",

                    ContentType =
                        "application/pdf",

                    IsApproved =
                        false
                });

            context
     .TherapistAvailabilities
     .Add(
         new TherapistAvailability
         {
             TherapistId =
                 therapistId,

             DayOfWeek =
                 appointmentStartUtc
                     .DayOfWeek,

             StartTime =
                 TimeSpan.Zero,

             EndTime =
                 new TimeSpan(
                     23,
                     59,
                     59)
         });

            await context
                .SaveChangesAsync();
        }

        using var anonymousClient =
            _factory.CreateClient();

        /*
         * ==================================================
         * 2. CLIENT REGISTRATION
         * ==================================================
         */

        var registerResponse =
            await anonymousClient
                .PostAsJsonAsync(
                    "/api/Auth/register",
                    new RegisterRequestDto
                    {
                        FirstName =
                            "Client",

                        LastName =
                            "EndToEnd",

                        Email =
                            clientEmail,

                        Username =
                            clientUsername,

                        Password =
                            clientPassword,

                        DateOfBirth =
                            new DateTime(
                                2000,
                                1,
                                1),

                        Gender =
                            "Female",

                        AcceptPrivacyPolicy =
                            true,

                        PrivacyPolicyVersion =
                            ConsentDocumentConstants
                                .PrivacyPolicyVersion,

                        AcceptTermsOfService =
                            true,

                        TermsOfServiceVersion =
                            ConsentDocumentConstants
                                .TermsOfServiceVersion
                    });

        Assert.Equal(
            HttpStatusCode.OK,
            registerResponse.StatusCode);

        var registration =
            await registerResponse.Content
                .ReadFromJsonAsync<
                    AuthResponseDto>();

        Assert.NotNull(
            registration);

        Assert.True(
            registration!.Id > 0);

        Assert.Equal(
            RoleConstants.Client,
            registration.Role);

        Assert.Equal(
            clientEmail,
            registration.Email);

        /*
         * ==================================================
         * 3. EMAIL VERIFICATION
         * ==================================================
         */

        var verificationEmail =
            notificationPublisher
                .Messages
                .LastOrDefault(message =>
                    string.Equals(
                        message.RecipientEmail,
                        clientEmail,
                        StringComparison
                            .OrdinalIgnoreCase));

        Assert.NotNull(
            verificationEmail);

        var codeMatch =
            Regex.Match(
                verificationEmail!.Body,
                @"\b\d{6}\b");

        Assert.True(
            codeMatch.Success,
            "Verification email did not contain "
            + "a six-digit verification code.");

        var verificationCode =
            codeMatch.Value;

        var verifyResponse =
            await anonymousClient
                .PostAsJsonAsync(
                    "/api/Auth/verify-email-code",
                    new
                    {
                        email =
                            clientEmail,

                        code =
                            verificationCode
                    });

        Assert.Equal(
            HttpStatusCode.OK,
            verifyResponse.StatusCode);

        /*
         * ==================================================
         * 4. CLIENT LOGIN
         * ==================================================
         */

        var loginResponse =
            await anonymousClient
                .PostAsJsonAsync(
                    "/api/Auth/login",
                    new LoginRequestDto
                    {
                        Email =
                            clientEmail,

                        Password =
                            clientPassword,

                        RememberMe =
                            false
                    });

        var clientLoginErrorBody =
            await loginResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            loginResponse.IsSuccessStatusCode,
            $"CLIENT LOGIN FAILED. "
            + $"Status: {(int)loginResponse.StatusCode} "
            + $"{loginResponse.StatusCode}. "
            + $"Body: {clientLoginErrorBody}");

        var clientLogin =
            await loginResponse.Content
                .ReadFromJsonAsync<
                    AuthResponseDto>();

        Assert.NotNull(
            clientLogin);

        Assert.False(
            string.IsNullOrWhiteSpace(
                clientLogin!.Token));

        Assert.Equal(
            RoleConstants.Client,
            clientLogin.Role);

        using var client =
            _factory.CreateBearerClient(
                clientLogin.Token);

        /*
         * ==================================================
         * 5. CLIENT ONBOARDING
         * ==================================================
         */

        var currentOnboardingResponse =
            await client.GetAsync(
                "/api/client-onboarding");

        var currentOnboardingBody =
            await currentOnboardingResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            currentOnboardingResponse
                .IsSuccessStatusCode,
            $"GET ONBOARDING FAILED. "
            + $"Status: "
            + $"{(int)currentOnboardingResponse.StatusCode} "
            + $"{currentOnboardingResponse.StatusCode}. "
            + $"Body: {currentOnboardingBody}");

        var currentOnboarding =
            await currentOnboardingResponse
                .Content
                .ReadFromJsonAsync<
                    ClientOnboardingDto>();

        Assert.NotNull(
            currentOnboarding);

        Assert.False(
            string.IsNullOrWhiteSpace(
                currentOnboarding!
                    .CurrentSensitiveDataProcessingVersion));

        var sensitiveDataVersion =
            currentOnboarding
                .CurrentSensitiveDataProcessingVersion;

        var onboardingResponse =
            await client
                .PutAsJsonAsync(
                    "/api/client-onboarding",
                    new SaveClientOnboardingDto
                    {
                        AssessmentFocusAreas =
                            [
                                "Anxiety"
                            ],

                        PreferredTherapistGender =
                            "Any",

                        PreferredSessionType =
                            "Online",

                        PreferredLanguages =
                            [
                                "English"
                            ],

                        MinimumPricePerSession =
                            0m,

                        MaximumPricePerSession =
                            100m,

                        Location =
                            "Mostar",

                        PreferredDays =
                            [
                                appointmentStartUtc
                                    .DayOfWeek
                            ],

                        PreferredTherapyApproachIds =
                            [
                                therapyApproachId
                            ],

                        CompleteOnboarding =
                            true,

                        AcceptSensitiveDataProcessing =
                            true,

                        SensitiveDataProcessingVersion =
                            sensitiveDataVersion
                    });

        var onboardingErrorBody =
            await onboardingResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            onboardingResponse
                .IsSuccessStatusCode,
            $"ONBOARDING FAILED. "
            + $"Status: "
            + $"{(int)onboardingResponse.StatusCode} "
            + $"{onboardingResponse.StatusCode}. "
            + $"Body: {onboardingErrorBody}");

        var onboarding =
            await onboardingResponse.Content
                .ReadFromJsonAsync<
                    ClientOnboardingDto>();

        Assert.NotNull(
            onboarding);

        Assert.True(
            onboarding!
                .HasCompletedOnboarding);

        Assert.NotNull(
            onboarding.CompletedAtUtc);

        Assert.Equal(
            "Online",
            onboarding
                .PreferredSessionType);

        Assert.Contains(
            "Anxiety",
            onboarding
                .AssessmentFocusAreas);

        Assert.Contains(
            therapyApproachId,
            onboarding
                .PreferredTherapyApproachIds);

        Assert.True(
            onboarding
                .HasAcceptedSensitiveDataProcessing);

        /*
         * ==================================================
         * 6. RECOMMENDATION
         * ==================================================
         */

        var recommendationResponse =
            await client
                .PostAsJsonAsync(
                    "/api/recommendations/therapists",
                    new TherapistRecommendationRequestDto
                    {
                        PreferredSpecializationIds =
                            [],

                        PreferredTherapyApproachIds =
                            [
                                therapyApproachId
                            ],

                        AssessmentFocusAreas =
                            [
                                "Anxiety"
                            ],

                        PreferredDays =
                            [
                                appointmentStartUtc
                                    .DayOfWeek
                            ],

                        MaximumPricePerSession =
                            100m,

                        MinimumExperienceYears =
                            1,

                        Take =
                            10
                    });

        var recommendationErrorBody =
            await recommendationResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            recommendationResponse
                .IsSuccessStatusCode,
            $"RECOMMENDATION FAILED. "
            + $"Status: "
            + $"{(int)recommendationResponse.StatusCode} "
            + $"{recommendationResponse.StatusCode}. "
            + $"Body: {recommendationErrorBody}");

        var recommendations =
            await recommendationResponse
                .Content
                .ReadFromJsonAsync<
                    List<
                        TherapistRecommendationDto>>();

        Assert.NotNull(
            recommendations);

        Assert.NotEmpty(
            recommendations!);

        var recommendedTherapist =
            recommendations!
                .SingleOrDefault(x =>
                    x.TherapistId ==
                    therapistId);

        Assert.NotNull(
            recommendedTherapist);

        Assert.Equal(
            therapistUserId,
            recommendedTherapist!
                .UserId);

        Assert.Contains(
            appointmentStartUtc
                .DayOfWeek,
            recommendedTherapist
                .AvailableDays);

        /*
         * ==================================================
         * 7. APPOINTMENT BOOKING
         * ==================================================
         */

        var idempotencyHeader =
            _factory
                .GetIdempotencyHeaderName();

        client.DefaultRequestHeaders
            .Remove(
                idempotencyHeader);

        client.DefaultRequestHeaders.Add(
            idempotencyHeader,
            $"appointment-{unique}");

        var appointmentResponse =
            await client
                .PostAsJsonAsync(
                    "/api/Appointments",
                    new CreateAppointmentDto
                    {
                        TherapistId =
                            recommendedTherapist
                                .TherapistId,

                        StartUtc =
                            appointmentStartUtc,

                        EndUtc =
                            appointmentEndUtc,

                        Type =
                            AppointmentType.Online,

                        MeetingLink =
                            null,

                        Location =
                            null,

                        Notes =
                            "E2E appointment."
                    });

        var appointmentErrorBody =
            await appointmentResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            appointmentResponse
                .IsSuccessStatusCode,
            $"APPOINTMENT BOOKING FAILED. "
            + $"Status: "
            + $"{(int)appointmentResponse.StatusCode} "
            + $"{appointmentResponse.StatusCode}. "
            + $"Body: {appointmentErrorBody}");

        var appointment =
            await appointmentResponse
                .Content
                .ReadFromJsonAsync<
                    AppointmentResponseDto>();

        Assert.NotNull(
            appointment);

        Assert.True(
            appointment!.Id > 0);

        Assert.Equal(
            therapistId,
            appointment.TherapistId);

        Assert.Equal(
            AppointmentStatus.Pending
                .ToString(),
            appointment.Status);

        var appointmentId =
            appointment.Id;

        /*
         * ==================================================
         * 8. THERAPIST LOGIN
         * ==================================================
         */

        var therapistLoginResponse =
            await anonymousClient
                .PostAsJsonAsync(
                    "/api/Auth/login",
                    new LoginRequestDto
                    {
                        Email =
                            therapistEmail,

                        Password =
                            therapistPassword,

                        RememberMe =
                            false
                    });

        var therapistLoginErrorBody =
            await therapistLoginResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            therapistLoginResponse
                .IsSuccessStatusCode,
            $"THERAPIST LOGIN FAILED. "
            + $"Status: "
            + $"{(int)therapistLoginResponse.StatusCode} "
            + $"{therapistLoginResponse.StatusCode}. "
            + $"Body: {therapistLoginErrorBody}");

        var therapistLogin =
            await therapistLoginResponse
                .Content
                .ReadFromJsonAsync<
                    AuthResponseDto>();

        Assert.NotNull(
            therapistLogin);

        Assert.Equal(
            RoleConstants.Therapist,
            therapistLogin!.Role);

        using var therapistClient =
            _factory.CreateBearerClient(
                therapistLogin.Token);

        /*
         * ==================================================
         * 9. THERAPIST ACCEPTS APPOINTMENT
         * ==================================================
         */

        var acceptResponse =
            await therapistClient
                .PutAsJsonAsync(
                    "/api/Appointments/status",
                    new UpdateAppointmentStatusDto
                    {
                        AppointmentId =
                            appointmentId,

                        Status =
                            AppointmentStatus
                                .Accepted
                    });

        var acceptErrorBody =
            await acceptResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            acceptResponse
                .IsSuccessStatusCode,
            $"APPOINTMENT ACCEPT FAILED. "
            + $"Status: "
            + $"{(int)acceptResponse.StatusCode} "
            + $"{acceptResponse.StatusCode}. "
            + $"Body: {acceptErrorBody}");

        Assert.Equal(
            HttpStatusCode.NoContent,
            acceptResponse.StatusCode);

        /*
         * ==================================================
         * 10. CLIENT STARTS PAYMENT
         * ==================================================
         */

        client.DefaultRequestHeaders
            .Remove(
                idempotencyHeader);

        client.DefaultRequestHeaders.Add(
            idempotencyHeader,
            $"payment-{unique}");

        var paymentIntentResponse =
            await client
                .PostAsJsonAsync(
                    "/api/Payments/create-intent",
                    new CreatePaymentIntentDto
                    {
                        AppointmentId =
                            appointmentId
                    });

        var paymentIntentErrorBody =
            await paymentIntentResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            paymentIntentResponse
                .IsSuccessStatusCode,
            $"PAYMENT INTENT FAILED. "
            + $"Status: "
            + $"{(int)paymentIntentResponse.StatusCode} "
            + $"{paymentIntentResponse.StatusCode}. "
            + $"Body: {paymentIntentErrorBody}");

        var paymentIntent =
            await paymentIntentResponse
                .Content
                .ReadFromJsonAsync<
                    PaymentIntentResponseDto>();

        Assert.NotNull(
            paymentIntent);

        Assert.False(
            string.IsNullOrWhiteSpace(
                paymentIntent!
                    .PaymentIntentId));

        Assert.False(
            string.IsNullOrWhiteSpace(
                paymentIntent
                    .ClientSecret));

        Assert.Equal(
            appointmentId,
            paymentIntent
                .AppointmentId);

        Assert.Equal(
            50m,
            paymentIntent.Amount);

        /*
         * ==================================================
         * 11. SERVER-SIDE PAYMENT CONFIRMATION
         * ==================================================
         */

        var confirmPaymentResponse =
            await client
                .PostAsJsonAsync(
                    "/api/Payments/confirm",
                    new ConfirmPaymentDto
                    {
                        PaymentIntentId =
                            paymentIntent
                                .PaymentIntentId
                    });

        var confirmPaymentErrorBody =
            await confirmPaymentResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            confirmPaymentResponse
                .IsSuccessStatusCode,
            $"PAYMENT CONFIRM FAILED. "
            + $"Status: "
            + $"{(int)confirmPaymentResponse.StatusCode} "
            + $"{confirmPaymentResponse.StatusCode}. "
            + $"Body: {confirmPaymentErrorBody}");

        Assert.Equal(
            HttpStatusCode.NoContent,
            confirmPaymentResponse
                .StatusCode);

        /*
         * ==================================================
         * 12. CHAT CONVERSATION
         * ==================================================
         */

        var conversationResponse =
            await client.PostAsync(
                "/api/Chat/appointments/"
                + $"{appointmentId}"
                + "/conversation",
                null);

        var conversationErrorBody =
            await conversationResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            conversationResponse
                .IsSuccessStatusCode,
            $"CHAT CONVERSATION FAILED. "
            + $"Status: "
            + $"{(int)conversationResponse.StatusCode} "
            + $"{conversationResponse.StatusCode}. "
            + $"Body: {conversationErrorBody}");

        var conversation =
            await conversationResponse
                .Content
                .ReadFromJsonAsync<
                    ConversationResponseDto>();

        Assert.NotNull(
            conversation);

        Assert.True(
            conversation!.Id > 0);

        Assert.Equal(
            appointmentId,
            conversation
                .AppointmentId);

        Assert.False(
            conversation.IsClosed);

        /*
         * ==================================================
         * 13. CLIENT SENDS CHAT MESSAGE
         * ==================================================
         */

        var clientMessageId =
            $"client-message-{unique}";

        var sendMessageResponse =
            await client
                .PostAsJsonAsync(
                    "/api/Chat/messages",
                    new SendChatMessageDto
                    {
                        ConversationId =
                            conversation.Id,

                        Content =
                            "Hello, this is the "
                            + "automated E2E client message.",

                        ClientMessageId =
                            clientMessageId
                    });

        var sendMessageErrorBody =
            await sendMessageResponse
                .Content
                .ReadAsStringAsync();

        Assert.True(
            sendMessageResponse
                .IsSuccessStatusCode,
            $"CHAT MESSAGE FAILED. "
            + $"Status: "
            + $"{(int)sendMessageResponse.StatusCode} "
            + $"{sendMessageResponse.StatusCode}. "
            + $"Body: {sendMessageErrorBody}");

        var chatMessage =
            await sendMessageResponse
                .Content
                .ReadFromJsonAsync<
                    ChatMessageResponseDto>();

        Assert.NotNull(
            chatMessage);

        Assert.True(
            chatMessage!.Id > 0);

        Assert.Equal(
            conversation.Id,
            chatMessage
                .ConversationId);

        Assert.Equal(
            clientLogin.Id,
            chatMessage
                .SenderUserId);

        Assert.Equal(
            clientMessageId,
            chatMessage
                .ClientMessageId);

        Assert.Contains(
            "automated E2E client message",
            chatMessage.Content,
            StringComparison
                .OrdinalIgnoreCase);

        /*
         * ==================================================
         * 14. THERAPIST COMPLETES APPOINTMENT
         * ==================================================
         */

        var completeResponse =
            await therapistClient
                .PutAsJsonAsync(
                    "/api/Appointments/status",
                    new UpdateAppointmentStatusDto
                    {
                        AppointmentId =
                            appointmentId,

                        Status =
                            AppointmentStatus
                                .Completed
                    });

        var completeErrorBody =
            await completeResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            completeResponse
                .IsSuccessStatusCode,
            $"APPOINTMENT COMPLETE FAILED. "
            + $"Status: "
            + $"{(int)completeResponse.StatusCode} "
            + $"{completeResponse.StatusCode}. "
            + $"Body: {completeErrorBody}");

        Assert.Equal(
            HttpStatusCode.NoContent,
            completeResponse
                .StatusCode);

        /*
         * ==================================================
         * 15. CLIENT CREATES REVIEW
         * ==================================================
         */

        var reviewResponse =
            await client
                .PostAsJsonAsync(
                    "/api/Reviews",
                    new CreateReviewDto
                    {
                        AppointmentId =
                            appointmentId,

                        Rating =
                            5,

                        Comment =
                            "Excellent E2E therapy session."
                    });

        var reviewErrorBody =
            await reviewResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            reviewResponse
                .IsSuccessStatusCode,
            $"REVIEW FAILED. "
            + $"Status: "
            + $"{(int)reviewResponse.StatusCode} "
            + $"{reviewResponse.StatusCode}. "
            + $"Body: {reviewErrorBody}");

        Assert.Equal(
            HttpStatusCode.Created,
            reviewResponse.StatusCode);

        Assert.Contains(
            "Review added successfully",
            reviewErrorBody,
            StringComparison
                .OrdinalIgnoreCase);

        /*
         * ==================================================
         * 16. ADMIN LOGIN
         * ==================================================
         */

        var adminLoginResponse =
            await anonymousClient
                .PostAsJsonAsync(
                    "/api/Auth/login",
                    new LoginRequestDto
                    {
                        Email =
                            adminEmail,

                        Password =
                            adminPassword,

                        RememberMe =
                            false
                    });

        var adminLoginErrorBody =
            await adminLoginResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            adminLoginResponse
                .IsSuccessStatusCode,
            $"ADMIN LOGIN FAILED. "
            + $"Status: "
            + $"{(int)adminLoginResponse.StatusCode} "
            + $"{adminLoginResponse.StatusCode}. "
            + $"Body: {adminLoginErrorBody}");

        var adminLogin =
            await adminLoginResponse.Content
                .ReadFromJsonAsync<
                    AuthResponseDto>();

        Assert.NotNull(
            adminLogin);

        Assert.Equal(
            RoleConstants.Admin,
            adminLogin!.Role);

        Assert.Equal(
            adminUserId,
            adminLogin.Id);

        using var adminClient =
            _factory.CreateBearerClient(
                adminLogin.Token);

        /*
         * ==================================================
         * 17. ADMIN VERIFIES THERAPIST
         * ==================================================
         */

        var verificationResponse =
            await adminClient
                .PutAsJsonAsync(
                    "/api/Admin/therapists/"
                    + $"{pendingTherapistId}"
                    + "/verification",
                    new UpdateTherapistVerificationDto
                    {
                        Status =
                            TherapistVerificationStatus
                                .Approved,

                        Notes =
                            "Approved by automated "
                            + "E2E administrator scenario."
                    });

        var verificationErrorBody =
            await verificationResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            verificationResponse
                .IsSuccessStatusCode,
            $"THERAPIST VERIFICATION FAILED. "
            + $"Status: "
            + $"{(int)verificationResponse.StatusCode} "
            + $"{verificationResponse.StatusCode}. "
            + $"Body: {verificationErrorBody}");

        Assert.Equal(
            HttpStatusCode.OK,
            verificationResponse.StatusCode);

        Assert.Contains(
            "Therapist approved successfully",
            verificationErrorBody,
            StringComparison
                .OrdinalIgnoreCase);

        /*
         * ==================================================
         * 18. ADMIN MODERATES REVIEW
         * ==================================================
         */

        int reviewId;

        using (var scope =
               _factory.Services
                   .CreateScope())
        {
            var context =
                scope.ServiceProvider
                    .GetRequiredService<
                        ApplicationDbContext>();

            reviewId =
                await context.Reviews
                    .AsNoTracking()
                    .Where(x =>
                        x.AppointmentId ==
                        appointmentId)
                    .Select(x =>
                        x.Id)
                    .SingleAsync();
        }

        var moderationResponse =
            await adminClient.PutAsync(
                "/api/Admin/reviews/"
                + $"{reviewId}"
                + "/approve",
                content:
                    null);

        var moderationErrorBody =
            await moderationResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            moderationResponse
                .IsSuccessStatusCode,
            $"REVIEW MODERATION FAILED. "
            + $"Status: "
            + $"{(int)moderationResponse.StatusCode} "
            + $"{moderationResponse.StatusCode}. "
            + $"Body: {moderationErrorBody}");

        Assert.Equal(
            HttpStatusCode.OK,
            moderationResponse.StatusCode);

        Assert.Contains(
            "Review approved successfully",
            moderationErrorBody,
            StringComparison
                .OrdinalIgnoreCase);

        /*
         * ==================================================
         * 19. ADMIN LOADS REPORT DATA
         * ==================================================
         */

        var reportFromUtc =
            appointmentStartUtc
                .AddDays(-1);

        var reportToUtc =
            appointmentEndUtc
                .AddDays(1);

        var reportUrl =
            "/api/admin/reports/appointments-revenue"
            + "?FromUtc="
            + Uri.EscapeDataString(
                reportFromUtc
                    .ToString("O"))
            + "&ToUtc="
            + Uri.EscapeDataString(
                reportToUtc
                    .ToString("O"));

        var reportResponse =
            await adminClient.GetAsync(
                reportUrl);

        var reportErrorBody =
            await reportResponse.Content
                .ReadAsStringAsync();

        Assert.True(
            reportResponse
                .IsSuccessStatusCode,
            $"ADMIN REPORT FAILED. "
            + $"Status: "
            + $"{(int)reportResponse.StatusCode} "
            + $"{reportResponse.StatusCode}. "
            + $"Body: {reportErrorBody}");

        var report =
            await reportResponse.Content
                .ReadFromJsonAsync<
                    AppointmentRevenueReportDto>();

        Assert.NotNull(
            report);

        Assert.True(
            report!.TotalAppointments >= 1);

        Assert.True(
            report.CompletedAppointments >= 1);

        Assert.True(
            report.PaymentSummary
                .PaidPaymentsCount >= 1);

        Assert.True(
            report.PaymentSummary
                .GrossRevenue > 0);

        Assert.Contains(
            report.Appointments,
            item =>
                item.AppointmentId ==
                appointmentId);

        /*
         * ==================================================
         * 20. FINAL DATABASE CONSISTENCY CHECK
         * ==================================================
         */

        using (var scope =
               _factory.Services
                   .CreateScope())
        {
            var context =
                scope.ServiceProvider
                    .GetRequiredService<
                        ApplicationDbContext>();

            var finalAppointment =
                await context.Appointments
                    .AsNoTracking()
                    .SingleAsync(x =>
                        x.Id ==
                        appointmentId);

            Assert.Equal(
                AppointmentStatus.Completed,
                finalAppointment.Status);

            Assert.True(
                finalAppointment.IsPaid);

            var finalPayment =
                await context.Payments
                    .AsNoTracking()
                    .SingleAsync(x =>
                        x.AppointmentId ==
                        appointmentId);

            Assert.Equal(
                PaymentStatus.Paid,
                finalPayment.Status);

            Assert.NotNull(
                finalPayment.PaidAtUtc);

            var finalReview =
                await context.Reviews
                    .AsNoTracking()
                    .SingleAsync(x =>
                        x.AppointmentId ==
                        appointmentId);

            Assert.Equal(
                5,
                finalReview.Rating);

            Assert.Equal(
                ReviewModerationStatus.Approved,
                finalReview
                    .ModerationStatus);

            Assert.True(
                finalReview.IsApproved);

            Assert.Equal(
                adminUserId,
                finalReview
                    .ModeratedByUserId);

            Assert.NotNull(
                finalReview
                    .ModeratedAtUtc);

            var verifiedTherapist =
                await context.Therapists
                    .AsNoTracking()
                    .SingleAsync(x =>
                        x.Id ==
                        pendingTherapistId);

            Assert.Equal(
                TherapistVerificationStatus.Approved,
                verifiedTherapist
                    .VerificationStatus);

            var verificationDocument =
                await context.TherapistDocuments
                    .AsNoTracking()
                    .SingleAsync(x =>
                        x.TherapistId ==
                        pendingTherapistId);

            Assert.True(
                verificationDocument
                    .IsApproved);

            Assert.True(
                await context
                    .TherapistVerificationAudits
                    .AsNoTracking()
                    .AnyAsync(x =>
                        x.TherapistId ==
                            pendingTherapistId
                        &&
                        x.AdminUserId ==
                            adminUserId
                        &&
                        x.NewStatus ==
                            TherapistVerificationStatus
                                .Approved));

            Assert.True(
                await context
                    .ReviewModerationAudits
                    .AsNoTracking()
                    .AnyAsync(x =>
                        x.ReviewId ==
                            finalReview.Id
                        &&
                        x.AdminUserId ==
                            adminUserId
                        &&
                        x.Action ==
                            ReviewModerationAction
                                .Approved));
        }
    }
}