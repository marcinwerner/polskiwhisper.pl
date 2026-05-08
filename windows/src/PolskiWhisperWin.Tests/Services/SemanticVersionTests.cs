// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using FluentAssertions;
using PolskiWhisperWin.Core.Utilities;
using Xunit;

namespace PolskiWhisperWin.Tests.Services;

public class SemanticVersionTests
{
    [Theory]
    [InlineData("0.1.0", 0, 1, 0)]
    [InlineData("v0.1.5", 0, 1, 5)]
    [InlineData("V1.2.3", 1, 2, 3)]
    [InlineData("0.1.5-beta", 0, 1, 5)]
    [InlineData("1.2.3+build.123", 1, 2, 3)]
    [InlineData("0.1", 0, 1, 0)]
    [InlineData("2", 2, 0, 0)]
    public void TryParse_ValidStrings_ReturnsExpectedComponents(string input, int major, int minor, int patch)
    {
        SemanticVersion.TryParse(input, out var version).Should().BeTrue();
        version.Major.Should().Be(major);
        version.Minor.Should().Be(minor);
        version.Patch.Should().Be(patch);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  ")]
    [InlineData("abc")]
    [InlineData("not.a.version")]
    public void TryParse_InvalidStrings_ReturnsFalse(string? input)
    {
        SemanticVersion.TryParse(input, out _).Should().BeFalse();
    }

    [Fact]
    public void Comparison_OlderIsLessThanNewer()
    {
        var v0_1_0 = SemanticVersion.Parse("0.1.0");
        var v0_2_0 = SemanticVersion.Parse("0.2.0");
        var v1_0_0 = SemanticVersion.Parse("1.0.0");

        (v0_1_0 < v0_2_0).Should().BeTrue();
        (v0_2_0 < v1_0_0).Should().BeTrue();
        (v0_1_0 < v1_0_0).Should().BeTrue();
    }

    [Fact]
    public void Comparison_PatchVersionsCompareCorrectly()
    {
        SemanticVersion.Parse("0.1.5").Should().BeGreaterThan(SemanticVersion.Parse("0.1.4"));
        SemanticVersion.Parse("0.1.5").Should().BeLessThan(SemanticVersion.Parse("0.1.6"));
        SemanticVersion.Parse("0.1.5").Should().Be(SemanticVersion.Parse("0.1.5"));
    }

    [Fact]
    public void ToString_ProducesCanonicalFormat()
    {
        SemanticVersion.Parse("v0.1.5-beta").ToString().Should().Be("0.1.5");
    }
}
