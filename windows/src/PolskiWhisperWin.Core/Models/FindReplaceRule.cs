// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Reguła Znajdź i zamień. Pojedynczy wpis w słowniku użytkownika.
/// Mapping 1:1 do macOS <c>FindReplaceRule</c> (tabela <c>find_replace_rule</c>).
/// </summary>
/// <param name="Id">Klucz główny w SQLite (auto-increment).</param>
/// <param name="FindText">Wzorzec do znalezienia (literal lub regex).</param>
/// <param name="ReplaceWith">Tekst zastępujący.</param>
/// <param name="IsRegex">Czy traktować <see cref="FindText"/> jako wyrażenie regularne (.NET regex).</param>
/// <param name="CaseSensitive">Czy uwzględniać wielkość liter podczas dopasowania.</param>
/// <param name="OrderIndex">Kolejność zastosowania reguł (rosnąco). Drag-and-drop modyfikuje tę wartość.</param>
/// <param name="CreatedAt">Timestamp utworzenia (UTC).</param>
public sealed record FindReplaceRule(
    long Id,
    string FindText,
    string ReplaceWith,
    bool IsRegex,
    bool CaseSensitive,
    int OrderIndex,
    DateTime CreatedAt
)
{
    /// <summary>Pusta reguła do tworzenia nowej w UI (ID == 0 oznacza "nowa, jeszcze nie zapisana").</summary>
    public static FindReplaceRule Empty => new(0, string.Empty, string.Empty, false, false, 0, DateTime.UtcNow);

    /// <summary>Czy reguła jest "ważna" (oba pola nie-puste). Używane w UI do walidacji.</summary>
    public bool IsValid => !string.IsNullOrWhiteSpace(FindText);
}
