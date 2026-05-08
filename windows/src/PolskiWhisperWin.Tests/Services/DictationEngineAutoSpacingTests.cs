// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Reflection;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PolskiWhisperWin.Core.Services;
using Xunit;

namespace PolskiWhisperWin.Tests.Services;

/// <summary>
/// Testy auto-spacing logic w DictationEngine. Mapping z macOS v0.1.2 testów.
/// </summary>
public class DictationEngineAutoSpacingTests
{
    private static DictationEngine BuildEngine()
    {
        return new DictationEngine(
            audioRecorder: Mock.Of<IAudioRecorder>(),
            whisperService: Mock.Of<IWhisperService>(),
            pasteService: Mock.Of<IPasteService>(),
            vocabularyStore: Mock.Of<IVocabularyStore>(),
            vocabularyProcessor: new VocabularyProcessor(NullLogger<VocabularyProcessor>.Instance),
            hallucinationFilter: new WhisperHallucinationFilter(NullLogger<WhisperHallucinationFilter>.Instance),
            logger: NullLogger<DictationEngine>.Instance);
    }

    [Fact]
    public void ApplyAutoSpacing_NoLastPaste_ReturnsInputUnchanged()
    {
        var engine = BuildEngine();
        engine.ApplyAutoSpacing("kolejne zdanie").Should().Be("kolejne zdanie");
    }

    [Fact]
    public void ApplyAutoSpacing_LastPasteEndedWithDot_PrependsSpace()
    {
        var engine = BuildEngine();

        // Symulujemy że poprzednie wklejenie skończyło się "."
        SetPrivateField(engine, "_lastPasteAt", System.DateTimeOffset.UtcNow);
        SetPrivateField(engine, "_lastPasteEndedWithTerminator", true);

        engine.ApplyAutoSpacing("kolejne zdanie").Should().Be(" kolejne zdanie");
    }

    [Fact]
    public void ApplyAutoSpacing_AlreadyStartsWithSpace_NoDoubleSpace()
    {
        var engine = BuildEngine();
        SetPrivateField(engine, "_lastPasteAt", System.DateTimeOffset.UtcNow);
        SetPrivateField(engine, "_lastPasteEndedWithTerminator", true);

        engine.ApplyAutoSpacing(" już ze spacją").Should().Be(" już ze spacją");
    }

    [Fact]
    public void ApplyAutoSpacing_OutsideWindow_ReturnsInputUnchanged()
    {
        var engine = BuildEngine();
        SetPrivateField(engine, "_lastPasteAt", System.DateTimeOffset.UtcNow.AddMinutes(-2));
        SetPrivateField(engine, "_lastPasteEndedWithTerminator", true);

        engine.ApplyAutoSpacing("kolejne").Should().Be("kolejne");
    }

    [Fact]
    public void ApplyAutoSpacing_LastPasteEndedWithoutTerminator_NoSpace()
    {
        var engine = BuildEngine();
        SetPrivateField(engine, "_lastPasteAt", System.DateTimeOffset.UtcNow);
        SetPrivateField(engine, "_lastPasteEndedWithTerminator", false);

        engine.ApplyAutoSpacing("dalej").Should().Be("dalej");
    }

    private static void SetPrivateField(object instance, string fieldName, object? value)
    {
        var field = instance.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new System.InvalidOperationException($"Field {fieldName} nie istnieje.");
        field.SetValue(instance, value);
    }
}
