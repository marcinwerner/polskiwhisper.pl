// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Utilities;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Implementacja <see cref="IUpdateChecker"/> używająca GitHub Releases API.
/// </summary>
public sealed class UpdateChecker : IUpdateChecker
{
    private const string ReleasesApiUrl =
        "https://api.github.com/repos/marcinwerner/polskiwhisper.pl/releases/latest";

    /// <summary>Prefix tag w GitHub release dla Windows wersji (np. <c>"win-v0.1.0"</c>).</summary>
    private const string WindowsTagPrefix = "win-";

    /// <summary>Suffix MSI w release assets - po tym filtrujemy.</summary>
    private const string MsiAssetSuffix = ".msi";

    private readonly HttpClient _httpClient;
    private readonly ILogger<UpdateChecker> _logger;

    public UpdateChecker(HttpClient httpClient, ILogger<UpdateChecker> logger)
    {
        _httpClient = httpClient;
        _logger = logger;

        if (_httpClient.DefaultRequestHeaders.UserAgent.Count == 0)
        {
            _httpClient.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("PolskiWhisperWin", "0.1.0"));
        }
    }

    /// <inheritdoc/>
    public async Task<UpdateInfo?> CheckForUpdateAsync(
        string currentVersion,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // GitHub API zwraca latest release - może być Mac LUB Windows. Filtrujemy
            // pobierając listę i wybierając najnowszy z prefixem "win-".
            var release = await GetLatestWindowsReleaseAsync(cancellationToken).ConfigureAwait(false);
            if (release is null) return null;

            var rawTag = release.TagName ?? string.Empty;
            var versionString = rawTag.StartsWith(WindowsTagPrefix, StringComparison.OrdinalIgnoreCase)
                ? rawTag[WindowsTagPrefix.Length..]
                : rawTag;

            if (!SemanticVersion.TryParse(versionString, out var latestVer)) return null;
            if (!SemanticVersion.TryParse(currentVersion, out var currentVer)) return null;

            var msiAsset = release.Assets?.FirstOrDefault(
                a => a.Name?.EndsWith(MsiAssetSuffix, StringComparison.OrdinalIgnoreCase) == true);

            if (msiAsset is null)
            {
                _logger.LogWarning("Najnowszy Windows release {Tag} nie ma MSI w assets.", rawTag);
                return null;
            }

            return new UpdateInfo(
                LatestVersion: latestVer.ToString(),
                CurrentVersion: currentVer.ToString(),
                ReleaseNotes: release.Body ?? string.Empty,
                DownloadUrl: msiAsset.BrowserDownloadUrl ?? string.Empty,
                ReleasedAt: release.PublishedAt ?? DateTimeOffset.MinValue,
                IsNewer: latestVer > currentVer
            );
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Sprawdzenie aktualizacji nie powiodło się.");
            return null;
        }
    }

    private async Task<GitHubRelease?> GetLatestWindowsReleaseAsync(CancellationToken cancellationToken)
    {
        // Pobieramy listę releases zamiast /latest, bo /latest może być wersją macOS.
        var listUrl = "https://api.github.com/repos/marcinwerner/polskiwhisper.pl/releases?per_page=20";

        var releases = await _httpClient.GetFromJsonAsync<GitHubRelease[]>(listUrl, cancellationToken)
            .ConfigureAwait(false);

        if (releases is null) return null;

        return releases
            .Where(r => !r.Draft && !r.Prerelease)
            .Where(r => r.TagName?.StartsWith(WindowsTagPrefix, StringComparison.OrdinalIgnoreCase) == true)
            .OrderByDescending(r => r.PublishedAt)
            .FirstOrDefault();
    }

    /// <inheritdoc/>
    public async Task<string> DownloadInstallerAsync(
        UpdateInfo updateInfo,
        IProgress<double>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var tempPath = Path.Combine(
            Path.GetTempPath(),
            $"PolskiWhisper-{updateInfo.LatestVersion}-installer.msi");

        if (File.Exists(tempPath)) File.Delete(tempPath);

        using var response = await _httpClient.GetAsync(
            updateInfo.DownloadUrl,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken).ConfigureAwait(false);

        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength ?? 0;

        await using var contentStream = await response.Content.ReadAsStreamAsync(cancellationToken)
            .ConfigureAwait(false);
        await using var fileStream = File.Create(tempPath);

        const int bufferSize = 81920;
        var buffer = new byte[bufferSize];
        long totalRead = 0;
        int read;
        var lastReportedAt = DateTimeOffset.UtcNow;

        while ((read = await contentStream.ReadAsync(buffer.AsMemory(0, bufferSize), cancellationToken)
                .ConfigureAwait(false)) > 0)
        {
            await fileStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
            totalRead += read;

            if (DateTimeOffset.UtcNow - lastReportedAt > TimeSpan.FromMilliseconds(250))
            {
                if (totalBytes > 0) progress?.Report((double)totalRead / totalBytes);
                lastReportedAt = DateTimeOffset.UtcNow;
            }
        }

        progress?.Report(1.0);
        _logger.LogInformation("Installer pobrany do {Path}.", tempPath);
        return tempPath;
    }

    // Minimalne DTO do parsowania GitHub Releases API.
    private sealed class GitHubRelease
    {
        [JsonPropertyName("tag_name")] public string? TagName { get; set; }
        [JsonPropertyName("name")] public string? Name { get; set; }
        [JsonPropertyName("body")] public string? Body { get; set; }
        [JsonPropertyName("draft")] public bool Draft { get; set; }
        [JsonPropertyName("prerelease")] public bool Prerelease { get; set; }
        [JsonPropertyName("published_at")] public DateTimeOffset? PublishedAt { get; set; }
        [JsonPropertyName("assets")] public GitHubAsset[]? Assets { get; set; }
    }

    private sealed class GitHubAsset
    {
        [JsonPropertyName("name")] public string? Name { get; set; }
        [JsonPropertyName("browser_download_url")] public string? BrowserDownloadUrl { get; set; }
        [JsonPropertyName("size")] public long Size { get; set; }
    }
}
