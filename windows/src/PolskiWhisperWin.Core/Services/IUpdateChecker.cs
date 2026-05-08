// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Sprawdza i pobiera aktualizacje aplikacji z GitHub Releases.
/// </summary>
public interface IUpdateChecker
{
    /// <summary>
    /// Pyta GitHub API o najnowszy release. Zwraca <c>UpdateInfo</c> z flagą czy nowsza niż obecna.
    /// </summary>
    /// <param name="currentVersion">Aktualna wersja aplikacji (z assembly).</param>
    /// <param name="cancellationToken">Anuluje request.</param>
    Task<UpdateInfo?> CheckForUpdateAsync(
        string currentVersion,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Pobiera MSI installer z release i zapisuje do <c>%TEMP%</c>. Zwraca ścieżkę.
    /// </summary>
    /// <param name="updateInfo">Info z <see cref="CheckForUpdateAsync"/>.</param>
    /// <param name="progress">Reporter postępu pobierania (0..1).</param>
    /// <param name="cancellationToken">Anuluje pobieranie.</param>
    Task<string> DownloadInstallerAsync(
        UpdateInfo updateInfo,
        IProgress<double>? progress = null,
        CancellationToken cancellationToken = default);
}
