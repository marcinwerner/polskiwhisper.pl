// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Wkleja tekst do aktywnego okna. Implementacja w głównym projekcie używa
/// TextCopy (clipboard) + InputSimulator (Ctrl+V keystrokes).
/// </summary>
public interface IPasteService
{
    /// <summary>
    /// Wstaw tekst na clipboard, opcjonalnie symuluj Ctrl+V.
    /// </summary>
    /// <param name="text">Tekst do wklejenia.</param>
    /// <param name="simulateKeystroke">
    /// <c>true</c> = wykonaj Ctrl+V po set clipboard (auto-paste). <c>false</c> = tylko clipboard, user paste sam.
    /// </param>
    Task PasteAsync(string text, bool simulateKeystroke = true);
}
