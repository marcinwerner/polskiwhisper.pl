// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using PolskiWhisperWin.Core.Services;
using Xunit;

namespace PolskiWhisperWin.Tests.Services;

public class WhisperHallucinationFilterTests
{
    private readonly WhisperHallucinationFilter _sut = new(NullLogger<WhisperHallucinationFilter>.Instance);

    [Theory]
    [InlineData("Dziękuję za oglądanie")]
    [InlineData("Dziekuje za ogladanie")]  // Bez polskich znaków
    [InlineData("Napisy stworzone przez społeczność Amara.org")]
    [InlineData("Thanks for watching")]
    [InlineData("Subscribe")]
    [InlineData("[Music]")]
    [InlineData("...")]
    [InlineData("a")]
    [InlineData("ok")]
    public void IsLikelyHallucination_KnownPhrases_ReturnsTrue(string text)
    {
        _sut.IsLikelyHallucination(text).Should().BeTrue();
    }

    [Theory]
    [InlineData("Cześć, jak się masz?")]
    [InlineData("Dzisiaj rano poszedłem na zakupy.")]
    [InlineData("Oferta dotyczy klientów biznesowych.")]
    public void IsLikelyHallucination_NormalText_ReturnsFalse(string text)
    {
        _sut.IsLikelyHallucination(text).Should().BeFalse();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  ")]
    public void IsLikelyHallucination_EmptyOrNull_ReturnsTrue(string? text)
    {
        _sut.IsLikelyHallucination(text).Should().BeTrue();
    }

    [Theory]
    [InlineData("Łódka", "lodka")]
    [InlineData("ŁADNIE", "ladnie")]
    [InlineData("Zażółć gęślą jaźń", "zazolc gesla jazn")]
    public void NormalizeForComparison_StripsDiacritics(string input, string expected)
    {
        WhisperHallucinationFilter.NormalizeForComparison(input).Should().Be(expected);
    }
}
