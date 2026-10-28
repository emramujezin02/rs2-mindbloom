using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Persistence.Seed;

public static class TherapistLocationSeed
{
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        const string country = "Bosnia and Herzegovina";
        foreach (var name in new[] { "Sarajevo", "Mostar" })
        {
            // Respect an administrator's existing entry, including inactive/deleted entries.
            if (!await context.TherapistLocations.AnyAsync(x => x.Name == name && x.Country == country && x.Region == ""))
                context.TherapistLocations.Add(new TherapistLocation { Name = name, Country = country });
        }
        await context.SaveChangesAsync();
        var locations = await context.TherapistLocations.Where(x => !x.IsDeleted).ToListAsync();
        var therapists = await context.Therapists.Where(x => x.LocationId == null).ToListAsync();
        foreach (var therapist in therapists)
        {
            var candidates = locations.Where(x => string.Equals(x.Name, therapist.City.Trim(), StringComparison.OrdinalIgnoreCase)
                && string.Equals(x.Country, therapist.Country.Trim(), StringComparison.OrdinalIgnoreCase)).ToList();
            var legacy = therapist.Location?.Trim();
            if (candidates.Count == 1 && (string.IsNullOrEmpty(legacy)
                || string.Equals(legacy, therapist.City.Trim(), StringComparison.OrdinalIgnoreCase)
                || string.Equals(legacy, $"{therapist.City.Trim()}, {therapist.Country.Trim()}", StringComparison.OrdinalIgnoreCase)))
                therapist.LocationId = candidates[0].Id;
        }
        await context.SaveChangesAsync();
    }
}
