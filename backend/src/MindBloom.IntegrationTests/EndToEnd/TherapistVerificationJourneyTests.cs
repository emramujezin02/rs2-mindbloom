using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class TherapistVerificationJourneyTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    private static int _nextClientAddress;

    [Theory]
    [InlineData(TherapistVerificationStatus.Approved)]
    [InlineData(TherapistVerificationStatus.Rejected)]
    public async Task RegistrationLoginPrivateDocumentsAndAdminDecision_WorkTogether(TherapistVerificationStatus decision)
    {
        await factory.EnsureRoleExistsAsync(RoleConstants.Therapist);
        var unique = Guid.NewGuid().ToString("N");
        var email = $"verification-{unique}@test.local";
        const string password = "JourneyPassword123!";
        using var anonymous = CreateActorClient();
        var request = new RegisterTherapistRequestDto
        {
            FirstName = "Test", LastName = "Therapist", Email = email, Username = $"verify_{unique}",
            Password = password, DateOfBirth = new DateTime(1990, 1, 1), Gender = "Other",
            Specialization = "Psychotherapy", Biography = "Synthetic test biography", HourlyRate = 50,
            ExperienceYears = 5, Country = "Test", City = "Test", Address = "Test", OffersOnline = true,
            AcceptPrivacyPolicy = true, PrivacyPolicyVersion = ConsentDocumentConstants.PrivacyPolicyVersion,
            AcceptTermsOfService = true, TermsOfServiceVersion = ConsentDocumentConstants.TermsOfServiceVersion
        };
        var registration = await anonymous.PostAsJsonAsync("/api/Auth/register-therapist", request);
        Assert.Equal(HttpStatusCode.Created, registration.StatusCode);
        var result = await registration.Content.ReadFromJsonAsync<RegisterTherapistResponseDto>();
        Assert.NotNull(result);
        Assert.Equal("Pending", result.VerificationStatus);
        using var registrationJson = JsonDocument.Parse(await registration.Content.ReadAsStringAsync());
        Assert.False(registrationJson.RootElement.TryGetProperty("token", out _));
        Assert.Equal(HttpStatusCode.Conflict, (await anonymous.PostAsJsonAsync("/api/Auth/register-therapist", request)).StatusCode);
        var duplicateName = request.Username;
        request.Email = $"different-{unique}@test.local";
        Assert.Equal(HttpStatusCode.Conflict, (await anonymous.PostAsJsonAsync("/api/Auth/register-therapist", request)).StatusCode);
        request.Username = duplicateName;
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto { Email = email, Password = password })).StatusCode);
        var publisher = factory.Services.GetRequiredService<TestNotificationPublisher>();
        var message = publisher.Messages.Last(x => x.RecipientEmail == email);
        Assert.NotNull(message.Body);
        var code = Regex.Match(message.Body, @"\b\d{6}\b");
        Assert.True(code.Success);
        Assert.Equal(HttpStatusCode.OK, (await anonymous.PostAsJsonAsync("/api/Auth/verify-email-code", new { email, code = code.Value })).StatusCode);
        using var therapist = await LoginAsync(anonymous, email, password, RoleConstants.Therapist);
        var adminEmail = $"admin-{unique}@test.local";
        await factory.SeedActiveUserAsync(RoleConstants.Admin, adminEmail, password);
        using var adminLoginClient = CreateActorClient();
        using var admin = await LoginAsync(adminLoginClient, adminEmail, password, RoleConstants.Admin);
        var clientEmail = $"client-{unique}@test.local";
        await factory.SeedActiveUserAsync(RoleConstants.Client, clientEmail, password);
        using var clientLoginClient = CreateActorClient();
        using var client = await LoginAsync(clientLoginClient, clientEmail, password, RoleConstants.Client);
        var paths = new List<string>();
        try
        {
            Assert.Equal(HttpStatusCode.NotFound, (await anonymous.GetAsync($"/api/Therapists/{result.TherapistId}")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PostAsync("/api/Therapists/documents", Document())).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsync("/api/Therapists/documents", Document())).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await admin.PostAsync("/api/Therapists/documents", Document())).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await therapist.PutAsJsonAsync($"/api/Admin/therapists/{result.TherapistId}/verification", new { status = 2 })).StatusCode);
            Assert.Equal(HttpStatusCode.Conflict, (await admin.PutAsJsonAsync($"/api/Admin/therapists/{result.TherapistId}/verification", new { status = 2 })).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await therapist.PostAsync("/api/Therapists/documents", Document(valid: false))).StatusCode);
            using var upload = Document();
            upload.Add(new StringContent("999999"), "TherapistId");
            Assert.Equal(HttpStatusCode.OK, (await therapist.PostAsync("/api/Therapists/documents", upload)).StatusCode);
            using (var scope = factory.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                var document = await db.TherapistDocuments.SingleAsync(x => x.TherapistId == result.TherapistId);
                paths.Add(document.FilePath);
                Assert.False(document.IsApproved);
                var privatePath = "/" + document.FilePath.Replace('\\', '/');
                Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync(privatePath)).StatusCode);
                Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync(privatePath)).StatusCode);
            }
            using var ownDocuments = JsonDocument.Parse(await therapist.GetStringAsync("/api/Therapists/documents/me?therapistId=999999"));
            Assert.Single(ownDocuments.RootElement.GetProperty("items").EnumerateArray());
            var documentId = ownDocuments.RootElement.GetProperty("items")[0].GetProperty("id").GetInt32();
            Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/Therapists/documents/me")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await therapist.GetAsync($"/api/Therapists/{result.TherapistId}/documents")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await therapist.GetAsync($"/api/Therapists/documents/{documentId}/download")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/Therapists/documents/{documentId}/download")).StatusCode);
            using var details = JsonDocument.Parse(await admin.GetStringAsync($"/api/Admin/therapists/{result.TherapistId}/verification"));
            Assert.Equal(documentId, details.RootElement.GetProperty("documents")[0].GetProperty("id").GetInt32());
            using var pending = JsonDocument.Parse(await admin.GetStringAsync("/api/Admin/therapists/pending?status=Pending"));
            Assert.Contains(pending.RootElement.GetProperty("items").EnumerateArray(), x => x.GetProperty("therapistId").GetInt32() == result.TherapistId);
            var downloaded = await admin.GetAsync($"/api/Therapists/documents/{documentId}/download");
            Assert.Equal(HttpStatusCode.OK, downloaded.StatusCode);
            Assert.Equal("application/pdf", downloaded.Content.Headers.ContentType?.MediaType);
            Assert.Equal(Encoding.ASCII.GetBytes("%PDF-1.4\nSynthetic verification document"), await downloaded.Content.ReadAsByteArrayAsync());
            if (decision == TherapistVerificationStatus.Approved)
            {
                Assert.Equal(HttpStatusCode.OK, (await admin.PutAsJsonAsync($"/api/Admin/therapists/{result.TherapistId}/verification", new { status = 4, notes = "Upload additional proof." })).StatusCode);
                using var requiresChanges = JsonDocument.Parse(await therapist.GetStringAsync("/api/Therapists/profile"));
                Assert.Equal("RequiresChanges", requiresChanges.RootElement.GetProperty("verificationStatus").GetString());
                Assert.Equal("Upload additional proof.", requiresChanges.RootElement.GetProperty("verificationNotes").GetString());
                Assert.Equal(HttpStatusCode.OK, (await therapist.PostAsync("/api/Therapists/documents", Document())).StatusCode);
                using var scope = factory.Services.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                paths = await db.TherapistDocuments.Where(x => x.TherapistId == result.TherapistId).Select(x => x.FilePath).ToListAsync();
                Assert.Equal(TherapistVerificationStatus.Pending, (await db.Therapists.AsNoTracking().SingleAsync(x => x.Id == result.TherapistId)).VerificationStatus);
            }
            Assert.Equal(HttpStatusCode.OK, (await admin.PutAsJsonAsync($"/api/Admin/therapists/{result.TherapistId}/verification", new { status = (int)decision, notes = "Synthetic verification decision." })).StatusCode);
            using (var scope = factory.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                var entity = await db.Therapists.AsNoTracking().Include(x => x.User).SingleAsync(x => x.Id == result.TherapistId);
                Assert.Equal(decision, entity.VerificationStatus);
                Assert.True(entity.User.IsActive);
                var approvals = await db.TherapistDocuments.Where(x => x.TherapistId == result.TherapistId).Select(x => x.IsApproved).ToListAsync();
                Assert.All(approvals, value => Assert.Equal(decision == TherapistVerificationStatus.Approved, value));
            }
            Assert.Equal(decision == TherapistVerificationStatus.Approved ? HttpStatusCode.OK : HttpStatusCode.NotFound,
                (await anonymous.GetAsync($"/api/Therapists/{result.TherapistId}")).StatusCode);
            if (decision == TherapistVerificationStatus.Rejected)
                Assert.Equal(HttpStatusCode.Conflict, (await therapist.PostAsync("/api/Therapists/documents", Document())).StatusCode);
        }
        finally
        {
            var root = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "private-storage")) + Path.DirectorySeparatorChar;
            foreach (var relative in paths)
            {
                var path = Path.GetFullPath(Path.Combine(root, relative));
                if (path.StartsWith(root, StringComparison.OrdinalIgnoreCase) && File.Exists(path)) File.Delete(path);
            }
        }
    }

    private HttpClient CreateActorClient()
    {
        // TestServer otherwise assigns every actor and scenario the same unknown IP.
        // Give each actor a distinct documentation address; keep real rate limits enabled.
        var address = IPAddress.Parse($"2001:db8::{Interlocked.Increment(ref _nextClientAddress):x}");
        return new HttpClient(factory.Server.CreateHandler(context => context.Connection.RemoteIpAddress = address))
        {
            BaseAddress = new Uri("http://localhost")
        };
    }

    private async Task<HttpClient> LoginAsync(HttpClient anonymous, string email, string password, string role)
    {
        var response = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto { Email = email, Password = password });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var login = await response.Content.ReadFromJsonAsync<Login2FAResponseDto>();
        Assert.NotNull(login);
        var auth = login.Auth;
        Assert.NotNull(auth);
        Assert.Equal(role, auth.Role);
        return factory.CreateBearerClient(auth.Token);
    }

    private static MultipartFormDataContent Document(bool valid = true)
    {
        var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(Encoding.ASCII.GetBytes(valid ? "%PDF-1.4\nSynthetic verification document" : "invalid file contents"));
        file.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        form.Add(file, "File", "synthetic-verification.pdf");
        return form;
    }
}
