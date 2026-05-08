// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Reprezentuje fazę cyklu życia dyktowania.
/// Mapping 1:1 do macOS <c>AppPhase</c> w Swift.
/// </summary>
public enum AppPhase
{
    /// <summary>Stan domyślny - aplikacja gotowa, brak aktywności.</summary>
    Idle,

    /// <summary>Trwa nagrywanie audio z mikrofonu.</summary>
    Recording,

    /// <summary>Audio nagrane, transkrypcja Whisper trwa.</summary>
    Processing,

    /// <summary>Tekst gotowy, trwa wklejanie (clipboard + Ctrl+V).</summary>
    Pasting,

    /// <summary>Wklejanie zakończone pomyślnie. Pokazujemy "✓" przez 600ms, potem Idle.</summary>
    Completed,

    /// <summary>Coś nie zadziałało. Pokazujemy komunikat błędu, potem Idle.</summary>
    Error
}
