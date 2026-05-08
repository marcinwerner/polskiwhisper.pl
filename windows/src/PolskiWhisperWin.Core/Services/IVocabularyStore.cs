// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Persystencja reguł <see cref="FindReplaceRule"/> w SQLite.
/// API mirroruje macOS <c>VocabularyStore</c> (GRDB.swift).
/// </summary>
public interface IVocabularyStore
{
    /// <summary>Inicjalizacja DB - tworzy tabelę i uruchamia migracje.</summary>
    Task InitializeAsync(CancellationToken cancellationToken = default);

    /// <summary>Wszystkie reguły w kolejności <c>OrderIndex ASC</c>.</summary>
    Task<IReadOnlyList<FindReplaceRule>> GetAllRulesAsync(CancellationToken cancellationToken = default);

    /// <summary>Dodaj nową regułę. Zwraca regułę z wypełnionym <c>Id</c>.</summary>
    Task<FindReplaceRule> AddRuleAsync(FindReplaceRule rule, CancellationToken cancellationToken = default);

    /// <summary>Aktualizuj istniejącą regułę (musi mieć <c>Id > 0</c>).</summary>
    Task UpdateRuleAsync(FindReplaceRule rule, CancellationToken cancellationToken = default);

    /// <summary>Usuń regułę po ID.</summary>
    Task DeleteRuleAsync(long ruleId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Zmień kolejność reguł. <paramref name="orderedIds"/> = ID-y w nowej kolejności
    /// (drag-and-drop emit z UI).
    /// </summary>
    Task ReorderRulesAsync(IReadOnlyList<long> orderedIds, CancellationToken cancellationToken = default);
}
