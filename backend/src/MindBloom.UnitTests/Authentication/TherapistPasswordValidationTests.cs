using FluentValidation;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Auth.Validators;

namespace MindBloom.UnitTests.Authentication;

public sealed class TherapistPasswordValidationTests
{
    public static IEnumerable<object[]> Cases()
    {
        yield return new object[] { "Abcdef1!", true };
        yield return new object[] { "Ab1!" + new string('a', 124), true };
        yield return new object[] { "Ab1!" + new string('a', 125), false };
        yield return new object[] { "Ab1!", false };
        yield return new object[] { "abcdef1!", false };
        yield return new object[] { "ABCDEF1!", false };
        yield return new object[] { "Abcdefg!", false };
        yield return new object[] { "Abcdef12", false };
        yield return new object[] { "", false };
        yield return new object[] { null!, false };
        yield return new object[] { "Ab1!😀" + new string('a', 122), true };
        yield return new object[] { "Ab1!😀" + new string('a', 123), false };
        yield return new object[] { "Abcdef1č", true };
        yield return new object[] { "Abcdef1 ", true };
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public void TherapistAndClientPasswords_UseIdenticalValidation(string password, bool expected)
    {
        var therapist = new RegisterTherapistRequestDtoValidator().Validate(
            new RegisterTherapistRequestDto { Password = password },
            options => options.IncludeProperties(x => x.Password));
        var client = new RegisterRequestDtoValidator().Validate(
            new RegisterRequestDto { Password = password },
            options => options.IncludeProperties(x => x.Password));
        Assert.Equal(expected, therapist.IsValid);
        Assert.Equal(client.Errors.Select(x => x.ErrorMessage), therapist.Errors.Select(x => x.ErrorMessage));
    }
}
