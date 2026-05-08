// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Informacja o dostępnej aktualizacji aplikacji (wynik z GitHub Releases API).
/// Mapping 1:1 do macOS <c>UpdateInfo</c>.
/// </summary>
/// <param name="LatestVersion">Najnowsza wersja w SemVer (np. "0.2.0").</param>
/// <param name="CurrentVersion">Wersja aktualnie zainstalowana.</param>
/// <param name="ReleaseNotes">Treść release notes z GitHub (markdown).</param>
/// <param name="DownloadUrl">URL do MSI installer w release assets.</param>
/// <param name="ReleasedAt">Data publikacji wydania (UTC).</param>
/// <param name="IsNewer">Czy <see cref="LatestVersion"/> jest nowsza niż <see cref="CurrentVersion"/>.</param>
public sealed record UpdateInfo(
    string LatestVersion,
    string CurrentVersion,
    string ReleaseNotes,
    string DownloadUrl,
    DateTimeOffset ReleasedAt,
    bool IsNewer
);
