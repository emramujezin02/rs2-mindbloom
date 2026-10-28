using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;

namespace MindBloom.UnitTests.Therapists;

public sealed partial class PublicTherapistVisibilityTests
{
    [Theory]
    [InlineData("valid")]
    [InlineData("unknown")]
    [InlineData("inactive")]
    [InlineData("deleted")]
    [InlineData("missing")]
    public async Task CreateTherapist_RequiresActiveReferenceAndDerivesName(string state)
    {
        await using var db = CreateContext(); var (_, client) = await SeedAsync(db);
        var spec = new TherapistSpecialization {Name="Reference name",IsActive=state!="inactive",IsDeleted=state=="deleted"};
        db.Add(spec); await db.SaveChangesAsync();
        var request = new CreateTherapistDto {SpecializationId=state=="missing" ? null : state=="unknown" ? 999 : spec.Id,
            Specialization="Untrusted text",Biography="Test",OffersOnline=true,Country="C",City="City",Address="Keep address"};
        var service = CreateService(db);
        if(state!="valid") {
            await Assert.ThrowsAsync<BadRequestException>(()=>service.CreateAsync(client.UserId,request));
            Assert.Single(await db.Therapists.ToListAsync()); return;
        }
        var result = await service.CreateAsync(client.UserId,request);
        Assert.Equal(spec.Id,result.SpecializationId); Assert.Equal(spec.Name,result.Specialization);
        var stored = await db.Therapists.SingleAsync(x=>x.UserId==client.UserId);
        Assert.Equal(spec.Id,stored.SpecializationId);
        Assert.Equal(MindBloom.Domain.Enums.TherapistVerificationStatus.Pending,stored.VerificationStatus);
    }

    [Fact]
    public async Task Profile_ChangesFkRetainsInactiveCurrentValueAndPreservesOtherFields()
    {
        await using var db = CreateContext(); var (therapist,_) = await SeedAsync(db);
        var spec = new TherapistSpecialization {Name="Chosen"}; var approach = new TherapyApproach {Name="Approach"};
        db.AddRange(spec,approach); await db.SaveChangesAsync();
        var request = new UpdateTherapistProfileDto {SpecializationId=spec.Id,Specialization="Untrusted",
            Biography="Keep biography",ExperienceYears=5,HourlyRate=50,Location="Keep location",Country="C",City="City",Address="Keep address",
            OffersOnline=true,WorksWithChildren=true,Languages=["English"],TherapyApproachIds=[approach.Id]};
        var service=CreateService(db); await service.UpdateProfileAsync(therapist.UserId,request);
        Assert.Equal(spec.Id,therapist.SpecializationId); Assert.Equal(spec.Name,therapist.Specialization);
        spec.IsActive=false; await db.SaveChangesAsync(); await service.UpdateProfileAsync(therapist.UserId,request);
        var profile=await service.GetProfileAsync(therapist.UserId);
        Assert.Equal(spec.Id,profile.SpecializationId); Assert.True(profile.WorksWithChildren); Assert.Equal("Keep address",profile.Address);
        request.SpecializationId=null; request.Specialization="Ignored";
        await service.UpdateProfileAsync(therapist.UserId,request);
        Assert.Equal(spec.Name,therapist.Specialization);
        var inactive=new TherapistSpecialization {Name="Other inactive",IsActive=false};
        db.Add(inactive); await db.SaveChangesAsync(); request.SpecializationId=inactive.Id;
        await Assert.ThrowsAsync<BadRequestException>(()=>service.UpdateProfileAsync(therapist.UserId,request));
        request.SpecializationId=int.MaxValue;
        await Assert.ThrowsAsync<BadRequestException>(()=>service.UpdateProfileAsync(therapist.UserId,request));
        Assert.Equal(spec.Id,therapist.SpecializationId);
    }
}
