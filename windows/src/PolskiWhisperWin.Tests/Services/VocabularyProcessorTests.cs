// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Collections.Generic;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using Xunit;

namespace PolskiWhisperWin.Tests.Services;

public class VocabularyProcessorTests
{
    private readonly VocabularyProcessor _sut = new(NullLogger<VocabularyProcessor>.Instance);

    [Fact]
    public void Apply_NoRules_ReturnsInput()
    {
        var result = _sut.Apply("Hello world", Array.Empty<FindReplaceRule>());
        result.Should().Be("Hello world");
    }

    [Fact]
    public void Apply_SimpleReplace_ReplacesText()
    {
        var rules = new[]
        {
            new FindReplaceRule(1, "ofertika", "Ofertica", false, false, 0, DateTime.UtcNow)
        };

        var result = _sut.Apply("Cena dla ofertika to 100 zł", rules);
        result.Should().Be("Cena dla Ofertica to 100 zł");
    }

    [Fact]
    public void Apply_CaseInsensitive_MatchesAllVariants()
    {
        var rules = new[]
        {
            new FindReplaceRule(1, "ofertika", "Ofertica", false, false, 0, DateTime.UtcNow)
        };

        _sut.Apply("Ofertika i OFERTIKA", rules).Should().Be("Ofertica i Ofertica");
    }

    [Fact]
    public void Apply_CaseSensitive_OnlyMatchesExact()
    {
        var rules = new[]
        {
            new FindReplaceRule(1, "ofertika", "Ofertica", false, true, 0, DateTime.UtcNow)
        };

        _sut.Apply("ofertika i Ofertika", rules).Should().Be("Ofertica i Ofertika");
    }

    [Fact]
    public void Apply_RegexRule_AppliesCorrectly()
    {
        var rules = new[]
        {
            new FindReplaceRule(1, @"\b(\d+)\s*z[lł]\b", "$1 zł", true, false, 0, DateTime.UtcNow)
        };

        _sut.Apply("Cena 100 zl albo 200 zł", rules).Should().Be("Cena 100 zł albo 200 zł");
    }

    [Fact]
    public void Apply_MultipleRules_AppliesInOrder()
    {
        var rules = new List<FindReplaceRule>
        {
            new(1, "ofertika", "Ofertica", false, false, 0, DateTime.UtcNow),
            new(2, "Ofertica", "OfertyMaster", false, true, 1, DateTime.UtcNow)
        };

        _sut.Apply("ofertika", rules).Should().Be("OfertyMaster");
    }

    [Fact]
    public void Apply_InvalidRegex_SkipsRuleAndContinues()
    {
        var rules = new List<FindReplaceRule>
        {
            new(1, "[invalid(regex", "X", true, false, 0, DateTime.UtcNow),
            new(2, "world", "świat", false, false, 1, DateTime.UtcNow)
        };

        _sut.Apply("Hello world", rules).Should().Be("Hello świat");
    }

    [Fact]
    public void Apply_EmptyInput_ReturnsEmpty()
    {
        var rules = new[] { new FindReplaceRule(1, "x", "y", false, false, 0, DateTime.UtcNow) };
        _sut.Apply("", rules).Should().Be("");
    }
}
