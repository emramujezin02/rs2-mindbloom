using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.Tests.Security;

public class UploadSecurityTests
{
    [Fact]
    public async Task ProfileImage_WithInvalidExtension_IsRejected()
    {
        var service = CreateUserProfileService(
            out var context,
            out var userManager);

        var user = CreateUser();

        userManager
            .Setup(x => x.FindByIdAsync("1"))
            .ReturnsAsync(user);

        var file = CreateFile(
            fileName: "malware.exe",
            contentType: "application/octet-stream",
            content: new byte[]
            {
                0x4D, 0x5A, 0x90, 0x00
            });

        await Assert.ThrowsAsync<BadRequestException>(
            () => service.UploadProfileImageAsync(
                1,
                file));

        context.Dispose();
    }

    [Fact]
    public async Task ProfileImage_WithInvalidMimeType_IsRejected()
    {
        var service = CreateUserProfileService(
            out var context,
            out var userManager);

        var user = CreateUser();

        userManager
            .Setup(x => x.FindByIdAsync("1"))
            .ReturnsAsync(user);

        var file = CreateFile(
            fileName: "image.jpg",
            contentType: "application/octet-stream",
            content: ValidJpegHeader());

        await Assert.ThrowsAsync<BadRequestException>(
            () => service.UploadProfileImageAsync(
                1,
                file));

        context.Dispose();
    }

    [Fact]
    public async Task ProfileImage_WithFakeJpegContent_IsRejected()
    {
        var service = CreateUserProfileService(
            out var context,
            out var userManager);

        var user = CreateUser();

        userManager
            .Setup(x => x.FindByIdAsync("1"))
            .ReturnsAsync(user);

        var file = CreateFile(
            fileName: "image.jpg",
            contentType: "image/jpeg",
            content: new byte[]
            {
                0x41,
                0x42,
                0x43,
                0x44,
                0x45,
                0x46,
                0x47,
                0x48
            });

        await Assert.ThrowsAsync<BadRequestException>(
            () => service.UploadProfileImageAsync(
                1,
                file));

        context.Dispose();
    }

    [Fact]
    public async Task ProfileImage_WithPathTraversalAndInvalidExtension_IsRejected()
    {
        var service = CreateUserProfileService(
            out var context,
            out var userManager);

        var user = CreateUser();

        userManager
            .Setup(x => x.FindByIdAsync("1"))
            .ReturnsAsync(user);

        var file = CreateFile(
            fileName: "../../secret.txt",
            contentType: "text/plain",
            content: new byte[]
            {
                0x41,
                0x42,
                0x43
            });

        await Assert.ThrowsAsync<BadRequestException>(
            () => service.UploadProfileImageAsync(
                1,
                file));

        context.Dispose();
    }

    [Fact]
    public async Task ProfileImage_WithWindowsPathTraversalAndInvalidExtension_IsRejected()
    {
        var service = CreateUserProfileService(
            out var context,
            out var userManager);

        var user = CreateUser();

        userManager
            .Setup(x => x.FindByIdAsync("1"))
            .ReturnsAsync(user);

        var file = CreateFile(
            fileName: @"..\..\secret.exe",
            contentType: "application/octet-stream",
            content: new byte[]
            {
                0x4D,
                0x5A,
                0x90,
                0x00
            });

        await Assert.ThrowsAsync<BadRequestException>(
            () => service.UploadProfileImageAsync(
                1,
                file));

        context.Dispose();
    }

    private static UserProfileService
        CreateUserProfileService(
            out ApplicationDbContext context,
            out Mock<UserManager<ApplicationUser>>
                userManager)
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    Guid.NewGuid().ToString())
                .Options;

        context =
            new ApplicationDbContext(options);

        var userStore =
            new Mock<IUserStore<ApplicationUser>>();

        userManager =
            new Mock<UserManager<ApplicationUser>>(
                userStore.Object,
                null!,
                null!,
                null!,
                null!,
                null!,
                null!,
                null!,
                null!);

        var environment =
            new Mock<IWebHostEnvironment>();

        environment
            .SetupGet(x => x.WebRootPath)
            .Returns(
                Path.Combine(
                    Path.GetTempPath(),
                    "MindBloomSecurityTests",
                    Guid.NewGuid().ToString()));

        return new UserProfileService(
            userManager.Object,
            environment.Object,
            context);
    }

    private static ApplicationUser CreateUser()
    {
        return new ApplicationUser
        {
            Id = 1,
            UserName = "security-test",
            Email = "security@test.local",
            FirstName = "Security",
            LastName = "Test"
        };
    }

    private static IFormFile CreateFile(
        string fileName,
        string contentType,
        byte[] content)
    {
        var stream =
            new MemoryStream(content);

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

    private static byte[] ValidJpegHeader()
    {
        return new byte[]
        {
            0xFF,
            0xD8,
            0xFF,
            0xE0,
            0x00,
            0x10,
            0x4A,
            0x46
        };
    }
}