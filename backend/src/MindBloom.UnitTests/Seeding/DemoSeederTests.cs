using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;

namespace MindBloom.UnitTests.Seeding;

// Real Identity with synthetic EF InMemory data only. No application host,
// SQL provider, Docker, HTTP client, Stripe or other integrations are registered.
public sealed class DemoSeederTests
{
    [Fact]
    public async Task Fresh_seed_creates_all_four_readme_accounts_with_valid_passwords_and_roles()
    {
        await using var f = new Fixture();
        await f.Seed();
        var rows = File.ReadLines(RepoFile("README.md"))
            .Where(line => line.StartsWith("| Admin |") || line.StartsWith("| Client |") || line.StartsWith("| Therapist |"))
            .Select(line => line.Split('|').Select(cell => cell.Trim().Trim('`')).ToArray()).ToArray();
        Assert.Equal(4, rows.Length);
        foreach (var row in rows)
        {
            var user = await f.Users.FindByEmailAsync(row[3]);
            Assert.NotNull(user);
            Assert.Equal(row[2], user.UserName);
            Assert.True(await f.Users.CheckPasswordAsync(user, row[4]), "README demo password must match Identity.");
            Assert.True(await f.Users.IsInRoleAsync(user, row[1]));
            Assert.True(user.IsActive && !user.IsBlocked && user.EmailConfirmed && user.IsEmailVerified);
        }
        var approved = await f.Users.FindByNameAsync("therapist.amina");
        var pending = await f.Users.FindByNameAsync("therapist.haris");
        Assert.Equal(TherapistVerificationStatus.Approved, (await f.Db.Therapists.SingleAsync(x => x.UserId == approved!.Id)).VerificationStatus);
        Assert.Equal(TherapistVerificationStatus.Pending, (await f.Db.Therapists.SingleAsync(x => x.UserId == pending!.Id)).VerificationStatus);
    }

    [Fact]
    public async Task Content_is_small_related_and_contains_no_fabricated_financial_transactions()
    {
        await using var f = new Fixture();
        // IDs need not start at one.
        f.Db.Users.Add(new ApplicationUser { UserName = "synthetic-offset", Email = "offset@example.invalid", FirstName = "Synthetic", LastName = "Offset" });
        await f.Db.SaveChangesAsync();
        await f.Seed();
        Assert.Equal(3, await f.Db.Therapists.CountAsync());
        Assert.Equal(8, await f.Db.Articles.CountAsync());
        Assert.All(await f.Db.Articles.ToListAsync(), x => Assert.True(x.IsPublished));
        Assert.Equal(4, await f.Db.TherapyApproaches.CountAsync(x => x.FeaturedArticleId != null));
        Assert.All(await f.Db.Therapists.ToListAsync(), x => { Assert.NotNull(x.SpecializationId); Assert.NotNull(x.LocationId); });
        var appointments = await f.Db.Appointments.ToListAsync();
        Assert.Equal(6, appointments.Count);
        Assert.All(appointments, x => { Assert.True(x.EndUtc > x.StartUtc); Assert.Equal(DateTimeKind.Utc, x.StartUtc.Kind); Assert.False(x.IsPaid); });
        Assert.All(appointments.Where(x => x.Status == AppointmentStatus.Completed), x => Assert.True(x.EndUtc < DateTime.UtcNow));
        Assert.All(appointments.Where(x => x.Status is AppointmentStatus.Accepted or AppointmentStatus.Pending), x => Assert.True(x.StartUtc > DateTime.UtcNow));
        var client = await f.Db.Clients.SingleAsync();
        Assert.All(appointments, x => Assert.Equal(client.Id, x.ClientId));
        Assert.Equal(2, await f.Db.Reviews.CountAsync());
        Assert.All(await f.Db.Reviews.ToListAsync(), x =>
        {
            var appointment = appointments.Single(a => a.Id == x.AppointmentId);
            Assert.Equal(AppointmentStatus.Completed, appointment.Status);
            Assert.Equal(appointment.ClientId, x.ClientId);
            Assert.Equal(appointment.TherapistId, x.TherapistId);
            Assert.False(x.ShareAuthorDemographics);
        });
        Assert.Equal(2, await f.Db.Notifications.CountAsync());
        Assert.Empty(await f.Db.Payments.ToListAsync());
        Assert.Empty(await f.Db.MembershipPayments.ToListAsync());
        Assert.Empty(await f.Db.ClientMemberships.ToListAsync());
        Assert.Empty(await f.Db.MembershipUsages.ToListAsync());
    }

    [Fact]
    public async Task Repeated_seed_preserves_passwords_moderation_read_state_and_reserved_prices()
    {
        await using var f = new Fixture();
        await f.Seed();
        var before = await f.Counts();
        var admin = (await f.Users.FindByNameAsync("desktop"))!;
        Assert.True((await f.Users.ChangePasswordAsync(admin, "MindBloom123!", "Synthetic-Changed2!")).Succeeded);
        var hash = admin.PasswordHash;
        var therapist = await f.Db.Therapists.FirstAsync();
        therapist.VerificationStatus = TherapistVerificationStatus.Pending;
        var notification = await f.Db.Notifications.FirstAsync();
        notification.IsRead = true;
        var appointment = await f.Db.Appointments.FirstAsync();
        appointment.Price = 71.25m;
        var article = await f.Db.Articles.FirstAsync();
        article.Title = "Edited synthetic article";
        await f.Db.SaveChangesAsync();
        await f.Seed();
        Assert.Equal(before, await f.Counts());
        Assert.Equal(hash, admin.PasswordHash);
        Assert.Equal(TherapistVerificationStatus.Pending, therapist.VerificationStatus);
        Assert.True(notification.IsRead);
        Assert.Equal(71.25m, appointment.Price);
        Assert.Equal("Edited synthetic article", article.Title);
    }

    [Fact]
    public async Task Existing_matching_demo_identity_can_receive_its_missing_role_without_password_reset()
    {
        await using var f = new Fixture();
        await f.Seed();
        var admin = (await f.Users.FindByNameAsync("desktop"))!;
        var hash = admin.PasswordHash;
        Assert.True((await f.Users.RemoveFromRoleAsync(admin, "Admin")).Succeeded);
        await f.Seed();
        Assert.True(await f.Users.IsInRoleAsync(admin, "Admin"));
        Assert.Equal(hash, admin.PasswordHash);
    }

    [Fact]
    public async Task Existing_conflicting_identity_is_rejected_without_reset_or_admin_promotion()
    {
        await using var f = new Fixture();
        var user = new ApplicationUser { UserName = "desktop", Email = "conflict@example.invalid", FirstName = "Synthetic", LastName = "Conflict" };
        Assert.True((await f.Users.CreateAsync(user, "Synthetic-Existing2!")).Succeeded);
        var hash = user.PasswordHash;
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Seed());
        Assert.Equal(hash, user.PasswordHash);
        Assert.False(await f.Users.IsInRoleAsync(user, "Admin"));
    }

    private static string RepoFile(string name)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null)
        {
            var path = Path.Combine(directory.FullName, name);
            if (File.Exists(path)) return path;
            directory = directory.Parent;
        }
        throw new FileNotFoundException(name);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private readonly ServiceProvider provider;
        public ApplicationDbContext Db { get; }
        public UserManager<ApplicationUser> Users { get; }
        private RoleManager<IdentityRole<int>> Roles { get; }
        public Fixture()
        {
            var services = new ServiceCollection();
            services.AddLogging();
            services.AddDbContext<ApplicationDbContext>(options => options.UseInMemoryDatabase($"demo-seed-{Guid.NewGuid():N}"));
            services.AddIdentityCore<ApplicationUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.Password.RequiredLength = 8;
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = true;
            }).AddRoles<IdentityRole<int>>().AddEntityFrameworkStores<ApplicationDbContext>();
            provider = services.BuildServiceProvider();
            Db = provider.GetRequiredService<ApplicationDbContext>();
            Users = provider.GetRequiredService<UserManager<ApplicationUser>>();
            Roles = provider.GetRequiredService<RoleManager<IdentityRole<int>>>();
        }
        public Task Seed() => ApplicationDbSeeder.SeedAsync(Db, Users, Roles);
        public async Task<int[]> Counts() => new[] {
            await Db.Users.CountAsync(), await Db.Roles.CountAsync(), await Db.Therapists.CountAsync(),
            await Db.Clients.CountAsync(), await Db.Articles.CountAsync(), await Db.Reviews.CountAsync(),
            await Db.Appointments.CountAsync(), await Db.Notifications.CountAsync(), await Db.Payments.CountAsync(),
            await Db.TherapistAvailabilities.CountAsync(), await Db.TherapistLocations.CountAsync(),
            await Db.MembershipPlans.CountAsync(), await Db.Workshops.CountAsync() };
        public ValueTask DisposeAsync() => provider.DisposeAsync();
    }
}