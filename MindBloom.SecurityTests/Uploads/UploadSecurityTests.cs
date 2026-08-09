using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Moq;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using Xunit;

namespace MindBloom.SecurityTests.Security;

public sealed class UploadSecurityTests
{
    [Fact]
    public async Task ProfileImage_InvalidExtension_IsRejected()
    {
        await using var context =
            CreateDbContext();

        var userManager =
            CreateUserManager();

        var environment =
            CreateEnvironment();

        var uploadSettings =
            CreateUploadSettings();

        var service =
            new UserProfileService(
                userManager,
                environment,
                context,
                uploadSettings);

        var file =
            CreateFile(
                fileName:
                    "profile.exe",
                contentType:
                    "application/octet-stream",
                content:
                    new byte[]
                    {
                        0x4D,
                        0x5A,
                        0x90,
                        0x00
                    });

        await Assert.ThrowsAnyAsync<Exception>(
            async () =>
            {
                await service
                    .UploadProfileImageAsync(
                        1,
                        file);
            });
    }

    [Fact]
    public async Task ProfileImage_FileLargerThanConfiguredLimit_IsRejected()
    {
        await using var context =
            CreateDbContext();

        var userManager =
            CreateUserManager();

        var environment =
            CreateEnvironment();

        var uploadSettings =
            Options.Create(
                new UploadSettings
                {
                    MaximumImageSizeMb = 1,
                    MaximumDocumentSizeMb = 10,
                    RootFolder = "uploads"
                });

        var service =
            new UserProfileService(
                userManager,
                environment,
                context,
                uploadSettings);

        var content =
            new byte[
                1024 * 1024 + 1];

        var file =
            CreateFile(
                fileName:
                    "profile.jpg",
                contentType:
                    "image/jpeg",
                content:
                    content);

        await Assert.ThrowsAnyAsync<Exception>(
            async () =>
            {
                await service
                    .UploadProfileImageAsync(
                        1,
                        file);
            });
    }

    [Fact]
    public async Task ProfileImage_ContentDoesNotMatchExtension_IsRejected()
    {
        await using var context =
            CreateDbContext();

        var userManager =
            CreateUserManager();

        var environment =
            CreateEnvironment();

        var uploadSettings =
            CreateUploadSettings();

        var service =
            new UserProfileService(
                userManager,
                environment,
                context,
                uploadSettings);

        var fakeJpegContent =
            new byte[]
            {
                0x89,
                0x50,
                0x4E,
                0x47,
                0x0D,
                0x0A,
                0x1A,
                0x0A
            };

        var file =
            CreateFile(
                fileName:
                    "profile.jpg",
                contentType:
                    "image/jpeg",
                content:
                    fakeJpegContent);

        await Assert.ThrowsAnyAsync<Exception>(
            async () =>
            {
                await service
                    .UploadProfileImageAsync(
                        1,
                        file);
            });
    }

    private static ApplicationDbContext
        CreateDbContext()
    {
        var options =
            new DbContextOptionsBuilder<
                ApplicationDbContext>()
                .UseInMemoryDatabase(
                    Guid.NewGuid()
                        .ToString())
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static UserManager<
        ApplicationUser>
        CreateUserManager()
    {
        var store =
            new Mock<
                IUserStore<
                    ApplicationUser>>();

        var passwordHasher =
            new Mock<
                IPasswordHasher<
                    ApplicationUser>>();

        var userValidators =
            Array.Empty<
                IUserValidator<
                    ApplicationUser>>();

        var passwordValidators =
            Array.Empty<
                IPasswordValidator<
                    ApplicationUser>>();

        var normalizer =
            new Mock<
                ILookupNormalizer>();

        var errors =
            new IdentityErrorDescriber();

        var services =
            new Mock<
                IServiceProvider>();

        var logger =
            new Mock<
                Microsoft.Extensions.Logging
                    .ILogger<
                        UserManager<
                            ApplicationUser>>>();

        return new UserManager<
            ApplicationUser>(
            store.Object,
            Options.Create(
                new IdentityOptions()),
            passwordHasher.Object,
            userValidators,
            passwordValidators,
            normalizer.Object,
            errors,
            services.Object,
            logger.Object);
    }

    private static IWebHostEnvironment
        CreateEnvironment()
    {
        var root =
            Path.Combine(
                Path.GetTempPath(),
                "mindbloom-security-tests",
                Guid.NewGuid()
                    .ToString("N"));

        Directory.CreateDirectory(
            root);

        var environment =
            new Mock<
                IWebHostEnvironment>();

        environment
            .SetupGet(
                x =>
                    x.WebRootPath)
            .Returns(root);

        environment
            .SetupGet(
                x =>
                    x.ContentRootPath)
            .Returns(root);

        return environment.Object;
    }

    private static IOptions<
        UploadSettings>
        CreateUploadSettings()
    {
        return Options.Create(
            new UploadSettings
            {
                MaximumImageSizeMb = 5,
                MaximumDocumentSizeMb = 10,
                RootFolder = "uploads"
            });
    }

    private static IFormFile
        CreateFile(
            string fileName,
            string contentType,
            byte[] content)
    {
        var stream =
            new MemoryStream(
                content);

        return new FormFile(
            stream,
            0,
            stream.Length,
            "file",
            fileName)
        {
            Headers =
                new HeaderDictionary(),

            ContentType =
                contentType
        };
    }
}