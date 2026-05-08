// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Wybór dźwięku dla zdarzenia (start nagrywania / koniec nagrywania).
/// 9 opcji jak w macOS app (v0.1.3) - mapowanie na pliki .wav w katalogu Assets/Sounds.
/// </summary>
public enum SoundChoice
{
    /// <summary>Brak dźwięku (cisza).</summary>
    None,

    /// <summary>Krótki "pop" - delikatny.</summary>
    Pop,

    /// <summary>Tink - metaliczny brzęk.</summary>
    Tink,

    /// <summary>Glass - jak rozbicie szkła.</summary>
    Glass,

    /// <summary>Ping - jak sonar.</summary>
    Ping,

    /// <summary>Bottle - jak postukanie w butelkę.</summary>
    Bottle,

    /// <summary>Purr - mruczenie kota.</summary>
    Purr,

    /// <summary>Hero - bohaterski akord.</summary>
    Hero,

    /// <summary>Submarine - sonar łodzi podwodnej.</summary>
    Submarine,

    /// <summary>Blow - dmuchnięcie.</summary>
    Blow
}

/// <summary>
/// Pomocnicze rozszerzenia dla <see cref="SoundChoice"/>.
/// </summary>
public static class SoundChoiceExtensions
{
    /// <summary>
    /// Zwraca polską nazwę dla UI (Picker dropdown).
    /// </summary>
    public static string ToDisplayName(this SoundChoice choice) => choice switch
    {
        SoundChoice.None => "Bez dźwięku",
        SoundChoice.Pop => "Pop",
        SoundChoice.Tink => "Tink",
        SoundChoice.Glass => "Glass",
        SoundChoice.Ping => "Ping",
        SoundChoice.Bottle => "Bottle",
        SoundChoice.Purr => "Purr",
        SoundChoice.Hero => "Hero",
        SoundChoice.Submarine => "Submarine",
        SoundChoice.Blow => "Blow",
        _ => choice.ToString()
    };

    /// <summary>
    /// Nazwa pliku .wav w katalogu Assets/Sounds. Dla <see cref="SoundChoice.None"/> zwraca null.
    /// </summary>
    public static string? ToFileName(this SoundChoice choice) => choice switch
    {
        SoundChoice.None => null,
        _ => $"{choice}.wav".ToLowerInvariant()
    };
}
