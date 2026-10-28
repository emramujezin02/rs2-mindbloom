using MindBloom.Infrastructure.Serialization;

namespace MindBloom.UnitTests.Recommendations;

public sealed class ClientPreferenceFormatTests
{
    [Theory]
    [InlineData(null, null)]
    [InlineData("", null)]
    [InlineData(" | , || ", null)]
    [InlineData("Bosnian", "Bosnian")]
    [InlineData("Bosnian|English", "Bosnian|English")]
    [InlineData("Bosnian, English", "Bosnian|English")]
    [InlineData("Serbian | English, Bosnian", "Bosnian|English|Serbian")]
    [InlineData(" Bosnian | bosnian ,, English | ", "Bosnian|English")]
    [InlineData("Anxiety", "Anxiety")]
    [InlineData("Anxiety, Stress", "Anxiety|Stress")]
    [InlineData("Anxiety|Stress", "Anxiety|Stress")]
    [InlineData("Unknown value", "Unknown value")]
    public void TextLists_ReadLegacyAndWriteCanonical(string? stored, string? canonical)
    {
        var parsed = ClientPreferenceFormat.SplitTextValues(stored);
        Assert.Equal(canonical, ClientPreferenceFormat.SerializeTextValues(parsed));
        Assert.Equal(parsed.Order(StringComparer.OrdinalIgnoreCase),
            ClientPreferenceFormat.SplitTextValues(ClientPreferenceFormat.SerializeTextValues(parsed)).Order(StringComparer.OrdinalIgnoreCase));
    }

    [Fact]
    public void NullAndEmptyCollections_SerializeAsNull()
    {
        Assert.Null(ClientPreferenceFormat.SerializeTextValues(null));
        Assert.Null(ClientPreferenceFormat.SerializeTextValues([]));
        Assert.Null(ClientPreferenceFormat.SerializeTextValues([null!, " "]));
        Assert.Null(ClientPreferenceFormat.SerializeDays(null));
        Assert.Null(ClientPreferenceFormat.SerializeDays([]));
    }

    [Theory]
    [InlineData(null, null)]
    [InlineData("", null)]
    [InlineData("Monday", "1")]
    [InlineData("Monday, Wednesday, Friday", "1,3,5")]
    [InlineData("1,3,5", "1,3,5")]
    [InlineData(" Friday | 1, MONDAY,, Wednesday ", "1,3,5")]
    [InlineData("Sunday, Saturday", "0,6")]
    [InlineData("0,1,2,3,4,5,6", "0,1,2,3,4,5,6")]
    [InlineData("Unknown, 7, -1, 99", null)]
    [InlineData("Unknown, Sunday, 8", "0")]
    public void Days_PreserveDotNetNumberingAndIgnoreUnknownTokens(string? stored, string? canonical)
    {
        Assert.Equal(canonical, ClientPreferenceFormat.SerializeDays(ClientPreferenceFormat.SplitDays(stored)));
    }
}
