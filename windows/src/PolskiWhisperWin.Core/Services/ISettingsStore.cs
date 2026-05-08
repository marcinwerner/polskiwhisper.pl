// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Persystencja <see cref="AppSettings"/> jako JSON.
/// Async API - dyskowe operacje nie blokują UI thread.
/// </summary>
public interface ISettingsStore
{
    /// <summary>Wczytaj settings z dysku. Jeśli plik nie istnieje, zwróć default <see cref="AppSettings"/>.</summary>
    Task<AppSettings> LoadAsync(CancellationToken cancellationToken = default);

    /// <summary>Zapisz settings do dysku (atomically - przez temp + rename).</summary>
    Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default);
}
