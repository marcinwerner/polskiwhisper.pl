// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Core.Utilities;
using Xunit;

namespace PolskiWhisperWin.Tests.Services;

public class SqliteVocabularyStoreTests : IAsyncLifetime
{
    private readonly string _tempDir;
    private SqliteVocabularyStore _sut = null!;

    public SqliteVocabularyStoreTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"pw-vocab-test-{Guid.NewGuid():N}");
    }

    public async Task InitializeAsync()
    {
        var paths = new AppPaths(_tempDir);
        _sut = new SqliteVocabularyStore(paths, NullLogger<SqliteVocabularyStore>.Instance);
        await _sut.InitializeAsync();
    }

    public Task DisposeAsync()
    {
        try
        {
            _sut?.DisposeAsync().AsTask().Wait();
            if (Directory.Exists(_tempDir)) Directory.Delete(_tempDir, recursive: true);
        }
        catch { /* best effort */ }
        return Task.CompletedTask;
    }

    [Fact]
    public async Task GetAllRulesAsync_EmptyStore_ReturnsEmpty()
    {
        var rules = await _sut.GetAllRulesAsync();
        rules.Should().BeEmpty();
    }

    [Fact]
    public async Task AddRuleAsync_GeneratesIdAndOrderIndex()
    {
        var rule = new FindReplaceRule(0, "ofertika", "Ofertica", false, false, 0, DateTime.UtcNow);
        var added = await _sut.AddRuleAsync(rule);

        added.Id.Should().BeGreaterThan(0);
        added.OrderIndex.Should().Be(0);
        added.FindText.Should().Be("ofertika");
    }

    [Fact]
    public async Task AddRule_MultipleRules_HaveIncrementingOrderIndex()
    {
        var r1 = await _sut.AddRuleAsync(new FindReplaceRule(0, "a", "A", false, false, 0, DateTime.UtcNow));
        var r2 = await _sut.AddRuleAsync(new FindReplaceRule(0, "b", "B", false, false, 0, DateTime.UtcNow));
        var r3 = await _sut.AddRuleAsync(new FindReplaceRule(0, "c", "C", false, false, 0, DateTime.UtcNow));

        r1.OrderIndex.Should().Be(0);
        r2.OrderIndex.Should().Be(1);
        r3.OrderIndex.Should().Be(2);
    }

    [Fact]
    public async Task UpdateRule_ChangesPersisted()
    {
        var added = await _sut.AddRuleAsync(new FindReplaceRule(0, "x", "X", false, false, 0, DateTime.UtcNow));
        // FindReplaceRule jest klasa (XAML data binding wymaga setterow) - mutacja inline zamiast `with`.
        added.ReplaceWith = "XYZ";
        added.IsRegex = true;

        await _sut.UpdateRuleAsync(added);

        var rules = await _sut.GetAllRulesAsync();
        rules.Should().HaveCount(1);
        rules[0].ReplaceWith.Should().Be("XYZ");
        rules[0].IsRegex.Should().BeTrue();
    }

    [Fact]
    public async Task DeleteRule_RemovesEntry()
    {
        var r1 = await _sut.AddRuleAsync(new FindReplaceRule(0, "a", "A", false, false, 0, DateTime.UtcNow));
        var r2 = await _sut.AddRuleAsync(new FindReplaceRule(0, "b", "B", false, false, 0, DateTime.UtcNow));

        await _sut.DeleteRuleAsync(r1.Id);

        var remaining = await _sut.GetAllRulesAsync();
        remaining.Should().HaveCount(1);
        remaining[0].Id.Should().Be(r2.Id);
    }

    [Fact]
    public async Task ReorderRules_ChangesOrder()
    {
        var r1 = await _sut.AddRuleAsync(new FindReplaceRule(0, "a", "A", false, false, 0, DateTime.UtcNow));
        var r2 = await _sut.AddRuleAsync(new FindReplaceRule(0, "b", "B", false, false, 0, DateTime.UtcNow));
        var r3 = await _sut.AddRuleAsync(new FindReplaceRule(0, "c", "C", false, false, 0, DateTime.UtcNow));

        await _sut.ReorderRulesAsync(new[] { r3.Id, r1.Id, r2.Id });

        var ordered = await _sut.GetAllRulesAsync();
        ordered.Select(r => r.FindText).Should().Equal("c", "a", "b");
    }
}
