// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Reguła Znajdź i zamień. Pojedynczy wpis w słowniku użytkownika.
/// Mapping 1:1 do macOS <c>FindReplaceRule</c> (tabela <c>find_replace_rule</c>).
/// </summary>
/// <remarks>
/// Klasa (nie record) bo XAML data binding wymaga settable properties (XamlTypeInfo.g.cs
/// generuje code-behind który próbuje setować właściwości po construction).
/// Zachowano positional constructor dla kompatybilności z istniejącymi callsites + testami.
/// </remarks>
public sealed class FindReplaceRule
{
    /// <summary>Klucz główny w SQLite (auto-increment).</summary>
    public long Id { get; set; }

    /// <summary>Wzorzec do znalezienia (literal lub regex).</summary>
    public string FindText { get; set; } = string.Empty;

    /// <summary>Tekst zastępujący.</summary>
    public string ReplaceWith { get; set; } = string.Empty;

    /// <summary>Czy traktować <see cref="FindText"/> jako wyrażenie regularne (.NET regex).</summary>
    public bool IsRegex { get; set; }

    /// <summary>Czy uwzględniać wielkość liter podczas dopasowania.</summary>
    public bool CaseSensitive { get; set; }

    /// <summary>Kolejność zastosowania reguł (rosnąco). Drag-and-drop modyfikuje tę wartość.</summary>
    public int OrderIndex { get; set; }

    /// <summary>Timestamp utworzenia (UTC).</summary>
    public DateTime CreatedAt { get; set; }

    public FindReplaceRule() { }

    // Parametry PascalCase aby zachowac kompatybilnosc z named-argument callsites z czasów records.
    public FindReplaceRule(long Id, string FindText, string ReplaceWith, bool IsRegex, bool CaseSensitive, int OrderIndex, DateTime CreatedAt)
    {
        this.Id = Id;
        this.FindText = FindText;
        this.ReplaceWith = ReplaceWith;
        this.IsRegex = IsRegex;
        this.CaseSensitive = CaseSensitive;
        this.OrderIndex = OrderIndex;
        this.CreatedAt = CreatedAt;
    }

    /// <summary>Pusta reguła do tworzenia nowej w UI (ID == 0 oznacza "nowa, jeszcze nie zapisana").</summary>
    public static FindReplaceRule Empty => new(0, string.Empty, string.Empty, false, false, 0, DateTime.UtcNow);

    /// <summary>Czy reguła jest "ważna" (oba pola nie-puste). Używane w UI do walidacji.</summary>
    public bool IsValid => !string.IsNullOrWhiteSpace(FindText);
}
