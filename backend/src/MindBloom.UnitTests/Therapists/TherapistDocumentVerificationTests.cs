using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;

namespace MindBloom.UnitTests.Therapists;

public sealed partial class PublicTherapistVisibilityTests
{
    [Theory]
    [InlineData("test.exe", "application/pdf", "pdf", 0)]
    [InlineData("test.pdf", "text/plain", "pdf", 0)]
    [InlineData("test.png", "image/png", "pdf", 0)]
    [InlineData("test.pdf", "application/pdf", "invalid", 0)]
    [InlineData("test.pdf", "application/pdf", "empty", 0)]
    [InlineData("test.pdf", "application/pdf", "pdf", 10485761)]
    public async Task InvalidDocuments_AreRejectedWithoutChangingApplication(string name, string mime, string data, int declaredLength)
    {
        await using var context = CreateContext();
        var therapist = (await SeedAsync(context)).Therapist;
        therapist.VerificationStatus = TherapistVerificationStatus.RequiresChanges;
        await context.SaveChangesAsync();
        var bytes = System.Text.Encoding.ASCII.GetBytes(data == "pdf" ? "%PDF-1.4 synthetic" : data == "empty" ? "" : "invalid");
        var file = new FormFile(new MemoryStream(bytes), 0, declaredLength == 0 ? bytes.Length : declaredLength, "File", name)
        { Headers = new HeaderDictionary(), ContentType = mime };
        await Assert.ThrowsAsync<BadRequestException>(() => CreateService(context).UploadDocumentAsync(therapist.UserId, file));
        Assert.Empty(context.TherapistDocuments);
        Assert.Equal(TherapistVerificationStatus.RequiresChanges, therapist.VerificationStatus);
    }

    [Theory]
    [InlineData(TherapistVerificationStatus.Pending)]
    [InlineData(TherapistVerificationStatus.RequiresChanges)]
    public async Task DocumentUpload_PreservesOwnershipAndReturnsApplicationToPending(TherapistVerificationStatus status)
    {
        await using var context = CreateContext();
        var (therapist, _) = await SeedAsync(context);
        therapist.VerificationStatus = status;
        await context.SaveChangesAsync();
        var service = CreateService(context);
        var bytes = "%PDF-1.4 synthetic"u8.ToArray();
        var file = new FormFile(new MemoryStream(bytes), 0, bytes.Length, "File", "synthetic.pdf") { Headers = new HeaderDictionary(), ContentType = "application/pdf" };
        string? path = null;
        try
        {
            await service.UploadDocumentAsync(therapist.UserId, file);
            var document = await context.TherapistDocuments.SingleAsync();
            path = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "private-storage", document.FilePath));
            Assert.True(File.Exists(path));
            Assert.Equal(therapist.Id, document.TherapistId);
            Assert.False(document.IsApproved);
            Assert.Equal(TherapistVerificationStatus.Pending, therapist.VerificationStatus);
            var own = await service.GetMyDocumentsAsync(therapist.UserId, 1, 10);
            Assert.Equal(document.Id, Assert.Single(own.Items).Id);
            Assert.Equal(string.Empty, own.Items[0].FilePath);
            Assert.Empty((await service.GetMyDocumentsAsync(therapist.UserId, 2, 10)).Items);
        }
        finally
        {
            var root = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "private-storage")) + Path.DirectorySeparatorChar;
            if (path?.StartsWith(root, StringComparison.OrdinalIgnoreCase) == true && File.Exists(path)) File.Delete(path);
        }
    }

    [Fact]
    public async Task MyDocuments_DoesNotExposeAnotherTherapistsDocuments()
    {
        await using var context = CreateContext();
        var first = (await SeedAsync(context)).Therapist;
        var second = (await SeedAsync(context)).Therapist;
        context.TherapistDocuments.Add(new TherapistDocument { TherapistId = second.Id, FileName = "private.pdf", FilePath = "not-public", ContentType = "application/pdf" });
        await context.SaveChangesAsync();
        Assert.Empty((await CreateService(context).GetMyDocumentsAsync(first.UserId, 1, 10)).Items);
        await Assert.ThrowsAsync<NotFoundException>(() => CreateService(context).GetMyDocumentsAsync(int.MaxValue, 1, 10));
    }

    [Fact]
    public async Task RejectedApplication_CannotBeResubmittedByUploading()
    {
        await using var context = CreateContext();
        var therapist = (await SeedAsync(context)).Therapist;
        therapist.VerificationStatus = TherapistVerificationStatus.Rejected;
        await context.SaveChangesAsync();
        var bytes = "%PDF-1.4 synthetic"u8.ToArray();
        var file = new FormFile(new MemoryStream(bytes), 0, bytes.Length, "File", "synthetic.pdf") { Headers = new HeaderDictionary(), ContentType = "application/pdf" };
        await Assert.ThrowsAsync<BusinessException>(() => CreateService(context).UploadDocumentAsync(therapist.UserId, file));
        Assert.Empty(context.TherapistDocuments);
        Assert.Equal(TherapistVerificationStatus.Rejected, therapist.VerificationStatus);
    }
}
