using System.Net;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using MindBloom.API.Messaging.Outbox;
using MindBloom.API.Messaging.RabbitMq;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.NotificationsWorker.Dispatching;
using MindBloom.NotificationsWorker.Handlers;
using MindBloom.NotificationsWorker.Messaging;
using MindBloom.NotificationsWorker.Monitoring;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Workers;

namespace MindBloom.GuiQaHost;

// Test infrastructure only. Runs production HTTP pipeline and Worker consumers against
// a newly owned fixture database and a separately provisioned RabbitMQ virtual host.
// No application startup, migrations, seeder, SMTP, Firebase or Stripe network calls.
public static class EntryPoint
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };

    public static async Task Main(string[] args)
    {
        if (args.Length != 1) throw new InvalidOperationException("Pass the external QA runtime JSON path.");
        var server = Environment.GetEnvironmentVariable("MINDBLOOM_E2E_SQL_SERVER_CONNECTION");
        if (string.IsNullOrWhiteSpace(server))
            throw new InvalidOperationException("The GUI runner requires an explicit localhost master connection; it never starts another SQL container.");
        var serverOptions = new SqlConnectionStringBuilder(server);
        if (serverOptions.DataSource is not "localhost,1433" and not "127.0.0.1,1433"
            || !string.Equals(serverOptions.InitialCatalog, "master", StringComparison.OrdinalIgnoreCase)
            || !string.IsNullOrEmpty(serverOptions.AttachDBFilename))
            throw new InvalidOperationException("The GUI runner requires the existing localhost SQL server and master catalog without an attached file.");
        var config = JsonSerializer.Deserialize<QaConfiguration>(await File.ReadAllTextAsync(args[0]), Json)!;
        if (!Regex.IsMatch(config.RunId, "^[a-f0-9]{32}$")
            || config.Rabbit.VirtualHost != $"qa-{config.RunId}"
            || config.Rabbit.UserName != $"qa-{config.RunId}"
            || config.Rabbit.HostName != "localhost" || config.Rabbit.Port != 5672
            || !Path.IsPathFullyQualified(config.RuntimeDirectory)
            || !string.Equals(Path.GetFullPath(Directory.GetCurrentDirectory()),
                Path.GetFullPath(config.RuntimeDirectory), StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("QA isolation configuration rejected.");

        Environment.SetEnvironmentVariable("JWT_SECRET", Convert.ToHexString(RandomNumberGenerator.GetBytes(48)));
        Environment.SetEnvironmentVariable("JWT_ISSUER", $"mindbloom-qa-{config.RunId}");
        Environment.SetEnvironmentVariable("JWT_AUDIENCE", $"mindbloom-qa-{config.RunId}");
        Environment.SetEnvironmentVariable("Seed__Enabled", "false");
        Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Testing");
        Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "Testing");
        Directory.CreateDirectory(Path.Combine(config.RuntimeDirectory, "wwwroot"));

        var repository = new DirectoryInfo(AppContext.BaseDirectory);
        while (repository is not null && !File.Exists(Path.Combine(repository.FullName, "MindBloom.sln"))) repository = repository.Parent;
        if (repository is null) throw new InvalidOperationException("Cannot locate the source repository.");
        if (Path.GetFullPath(config.RuntimeDirectory).StartsWith(repository.FullName + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("QA runtime files must be outside the repository.");
        var fixture = MindBloomEndToEndTestFactory.ForGuiRunner(Path.Combine(repository.FullName, "backend", "src", "MindBloom.API"));
        try
        {
            await fixture.InitializeAsync();
            using (var scope = fixture.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                var name = db.Database.GetDbConnection().Database;
                if (!Regex.IsMatch(name, "^MindBloomE2E_[a-f0-9]{32}$"))
                    throw new InvalidOperationException("Refusing a non-fixture database.");
                await File.WriteAllTextAsync(Path.Combine(config.RuntimeDirectory, "owned-database.txt"), name);
            }
            await SeedAsync(fixture, config);

            await using var live = fixture.WithWebHostBuilder(builder =>
            {
                builder.UseWebRoot(Path.Combine(config.RuntimeDirectory, "wwwroot"));
                builder.ConfigureLogging(logging =>
                {
                    logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
                    logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.Warning);
                });
                builder.ConfigureServices(services =>
                {
                    services.RemoveAll<IOptions<RabbitMqOptions>>();
                    services.AddSingleton<IOptions<RabbitMqOptions>>(Options.Create(config.Rabbit));
                    services.RemoveAll<IIntegrationEventPublisher>();
                    services.AddSingleton<IIntegrationEventPublisher, RabbitMqIntegrationEventPublisher>();
                    services.RemoveAll<IPushNotificationService>();
                    services.AddScoped<IPushNotificationService, NoOpPushNotificationService>();
                    services.RemoveAll<IEmailService>();
                    services.AddSingleton<IEmailService, NoOpEmailService>();
                    services.AddSingleton<RabbitMqConsumerOperations>();
                    services.AddSingleton<RabbitMqWorkerConnectionProvider>();
                    services.AddSingleton<EmailMessageBodyBuilder>();
                    services.AddScoped<WorkerNotificationService>();
                    services.AddSingleton<IntegrationEventDeserializer>();
                    services.AddSingleton<IIntegrationEventDispatcher, IntegrationEventDispatcher>();
                    services.AddScoped<ProcessedMessageService>();
                    services.AddSingleton<RabbitMqMonitoringMetrics>();
                    var handlerType = typeof(IIntegrationEventHandler<>);
                    foreach (var type in typeof(WorkerNotificationService).Assembly.GetTypes()
                        .Where(t => t is { IsClass: true, IsAbstract: false }))
                        foreach (var contract in type.GetInterfaces().Where(i => i.IsGenericType && i.GetGenericTypeDefinition() == handlerType))
                            services.AddScoped(contract, type);
                    services.AddHostedService<IntegrationEventConsumer>();
                    services.AddHostedService<EmailNotificationConsumer>();
                    services.AddHostedService<OutboxMessageProcessor>();
                });
            });
            using var upstream = live.CreateClient();
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Testing", Args = [] });
            builder.WebHost.UseUrls("http://127.0.0.1:8082");
            builder.Logging.ClearProviders();
            await using var app = builder.Build();
            app.UseWebSockets();
            app.Run(async context =>
            {
                // QA controls are loopback-only and guarded by an unguessable run key.
                if (context.Request.Path.StartsWithSegments("/__qa"))
                {
                    if (!IPAddress.IsLoopback(context.Connection.RemoteIpAddress!)
                        || context.Request.Headers["X-Qa-Key"] != config.ControlKey)
                    { context.Response.StatusCode = 404; return; }
                    if (context.Request.Path == "/__qa/stop" && context.Request.Method == "POST")
                    { await context.Response.WriteAsync("stopping"); app.Lifetime.StopApplication(); return; }
                    if (context.Request.Path == "/__qa/email-code")
                    {
                        var email = context.Request.Query["email"].ToString();
                        if (!email.EndsWith("@test.local", StringComparison.Ordinal)) { context.Response.StatusCode = 400; return; }
                        var message = live.Services.GetRequiredService<TestNotificationPublisher>().Messages.LastOrDefault(x => x.RecipientEmail == email);
                        var code = Regex.Match(message?.Body ?? "", @"\b\d{6}\b").Value;
                        await context.Response.WriteAsJsonAsync(new { code }); return;
                    }
                    if (context.Request.Path == "/__qa/state")
                    {
                        using var scope = live.Services.CreateScope();
                        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                        await context.Response.WriteAsJsonAsync(new
                        {
                            database = db.Database.GetDbConnection().Database,
                            appointments = await db.Appointments.CountAsync(),
                            notifications = await db.Notifications.CountAsync(),
                            outbox = await db.OutboxMessages.Select(x => new { x.Id, x.RoutingKey, x.ProcessedAtUtc }).ToListAsync()
                        }); return;
                    }
                    context.Response.StatusCode = 404; return;
                }
                if (context.WebSockets.IsWebSocketRequest)
                {
                    var client = live.Server.CreateWebSocketClient();
                    client.ConfigureRequest = request =>
                    {
                        foreach (var header in context.Request.Headers)
                            if (!header.Key.StartsWith("Sec-WebSocket", StringComparison.OrdinalIgnoreCase)
                                && header.Key is not "Connection" and not "Upgrade" and not "Host")
                                request.Headers[header.Key] = header.Value;
                    };
                    using var remote = await client.ConnectAsync(new Uri($"ws://localhost{context.Request.Path}{context.Request.QueryString}"), context.RequestAborted);
                    using var local = await context.WebSockets.AcceptWebSocketAsync();
                    using var cancellation = CancellationTokenSource.CreateLinkedTokenSource(context.RequestAborted);
                    await Task.WhenAny(CopySocket(local, remote, cancellation.Token), CopySocket(remote, local, cancellation.Token));
                    cancellation.Cancel();
                    return;
                }
                using var request = new HttpRequestMessage(new HttpMethod(context.Request.Method), $"{context.Request.Path}{context.Request.QueryString}");
                if (context.Request.ContentLength > 0 || context.Request.Headers.ContainsKey("Transfer-Encoding"))
                    request.Content = new StreamContent(context.Request.Body);
                foreach (var header in context.Request.Headers)
                {
                    if (header.Key is "Host" or "Connection" or "Transfer-Encoding") continue;
                    if (!request.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray()))
                        request.Content?.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray());
                }
                using var response = await upstream.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, context.RequestAborted);
                context.Response.StatusCode = (int)response.StatusCode;
                foreach (var header in response.Headers.Concat(response.Content.Headers))
                    if (header.Key is not "Transfer-Encoding" and not "Connection") context.Response.Headers[header.Key] = header.Value.ToArray();
                await response.Content.CopyToAsync(context.Response.Body, context.RequestAborted);
            });
            await app.StartAsync();
            await File.WriteAllTextAsync(Path.Combine(config.RuntimeDirectory, "ready.json"), JsonSerializer.Serialize(new
            { port = 8082, config.RunId, database = await File.ReadAllTextAsync(Path.Combine(config.RuntimeDirectory, "owned-database.txt")), realRabbit = true, realWorker = true, externalEmail = false, externalPush = false, externalStripe = false }, Json));
            Console.WriteLine("QA_READY loopback:8082; isolated SQL/RabbitMQ; external integrations disabled.");
            await app.WaitForShutdownAsync();
        }
        finally
        {
            await fixture.DisposeAsync();
            await File.WriteAllTextAsync(Path.Combine(config.RuntimeDirectory, "database-cleanup.txt"), "Owned fixture database disposed.");
        }
    }

    private static async Task CopySocket(WebSocket source, WebSocket target, CancellationToken token)
    {
        var buffer = new byte[8192];
        try
        {
            while (!token.IsCancellationRequested)
            {
                var received = await source.ReceiveAsync(buffer.AsMemory(), token);
                if (received.MessageType == WebSocketMessageType.Close) break;
                await target.SendAsync(buffer.AsMemory(0, received.Count), received.MessageType, received.EndOfMessage, token);
            }
        }
        catch (OperationCanceledException) { }
        catch (WebSocketException) { }
    }

    private static async Task SeedAsync(MindBloomEndToEndTestFactory fixture, QaConfiguration config)
    {
        var adminId = await fixture.SeedActiveUserAsync("Admin", config.AdminEmail, config.Password);
        var therapistUserId = await fixture.SeedActiveUserAsync("Therapist", config.TherapistEmail, config.Password);
        var clientUserId = await fixture.SeedActiveUserAsync("Client", config.ClientEmail, config.Password);
        using var scope = fixture.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var specialization = new TherapistSpecialization { Name = "QA Psychotherapy", IsActive = true };
        db.Add(specialization);
        var location = new TherapistLocation { Name = "Sarajevo", Country = "Bosnia and Herzegovina", Region = "QA" };
        db.Add(location);
        var therapistUser = await db.Users.SingleAsync(x => x.Id == therapistUserId);
        therapistUser.FirstName = "QA"; therapistUser.LastName = "Therapist";
        var clientUser = await db.Users.SingleAsync(x => x.Id == clientUserId);
        clientUser.FirstName = "QA"; clientUser.LastName = "Client";
        var therapist = new Therapist { UserId = therapistUserId, Biography = "Synthetic QA therapist biography.",
            Specialization = "Psychotherapy", SpecializationReference = specialization,
            HourlyRate = 80, PricePerSession = 80, ExperienceYears = 5,
            VerificationStatus = TherapistVerificationStatus.Approved, Country = "Bosnia and Herzegovina",
            City = "Sarajevo", Address = "QA address", Location = "Sarajevo", LocationReference = location,
            OffersOnline = true, OffersInPerson = true, Languages = "Bosnian,English" };
        var client = new Client { UserId = clientUserId, HasCompletedOnboarding = true, Location = "Sarajevo" };
        db.AddRange(therapist, client);
        await db.SaveChangesAsync();
        foreach (var day in Enum.GetValues<DayOfWeek>()) db.Add(new TherapistAvailability { TherapistId = therapist.Id,
            DayOfWeek = day, StartTime = TimeSpan.FromHours(9), EndTime = TimeSpan.FromHours(17) });
        var category = new ArticleCategory { Name = "Therapy Approaches" };
        db.Add(category);
        var approaches = new[] { "CBT", "Gestalt", "Person-Centered", "ACT" };
        foreach (var name in approaches)
        {
            var article = new Article { Title = $"QA {name} educational article", Description = $"Synthetic QA article about {name}.",
                Content = $"This synthetic article verifies navigation for {name}. It is not medical advice.",
                AuthorUserId = adminId, ArticleCategory = category, IsPublished = true, PublishedAtUtc = DateTime.UtcNow };
            var approach = new TherapyApproach { Name = name, Description = $"QA {name} description.", FeaturedArticle = article };
            db.Add(new TherapistTherapyApproach { TherapistId = therapist.Id, TherapyApproach = approach });
        }
        // Enough records for real server pagination and related articles; no network images.
        for (var i = 1; i <= 12; i++) db.Add(new Article { Title = $"QA general article {i}", Description = "Synthetic pagination content.",
            Content = "Synthetic article body for GUI verification.", AuthorUserId = adminId, ArticleCategory = category,
            IsPublished = true, PublishedAtUtc = DateTime.UtcNow.AddMinutes(-i) });
        var membership = new ClientMembership { ClientId = client.Id, TherapistId = therapist.Id, PlanType = MembershipPlanType.TenSessions,
            TotalSessions = 10, RemainingSessions = 10, Price = 600, DurationMonths = 3, IsActive = true,
            PurchasedAtUtc = DateTime.UtcNow, ExpiresAtUtc = DateTime.UtcNow.AddMonths(3) };
        db.Add(new MembershipPayment { ClientMembership = membership, Amount = 600, Status = PaymentStatus.Paid,
            StripePaymentIntentId = $"pi_qa_synthetic_{config.RunId}", PaidAtUtc = DateTime.UtcNow });
        await db.SaveChangesAsync();
        await File.WriteAllTextAsync(Path.Combine(config.RuntimeDirectory, "seed.json"), JsonSerializer.Serialize(new
        { adminId, therapistUserId, clientUserId, therapistId = therapist.Id, clientId = client.Id, specializationId = specialization.Id, membershipId = membership.Id }, Json));
    }
}

public sealed class QaConfiguration
{
    public required string RunId { get; init; }
    public required string RuntimeDirectory { get; init; }
    public required string ControlKey { get; init; }
    public required RabbitMqOptions Rabbit { get; init; }
    public required string Password { get; init; }
    public required string AdminEmail { get; init; }
    public required string TherapistEmail { get; init; }
    public required string ClientEmail { get; init; }
}
