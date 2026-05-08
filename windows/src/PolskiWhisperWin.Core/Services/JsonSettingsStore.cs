// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Utilities;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// JSON-based <see cref="ISettingsStore"/>. Plik settings.json w
/// <c>%LOCALAPPDATA%\PolskiWhisper\</c>. Atomic write (temp + replace).
/// </summary>
public sealed class JsonSettingsStore : ISettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly IAppPaths _paths;
    private readonly ILogger<JsonSettingsStore> _logger;
    private readonly SemaphoreSlim _diskLock = new(1, 1);

    public JsonSettingsStore(IAppPaths paths, ILogger<JsonSettingsStore> logger)
    {
        _paths = paths;
        _logger = logger;
    }

    /// <inheritdoc/>
    public async Task<AppSettings> LoadAsync(CancellationToken cancellationToken = default)
    {
        await _diskLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureDirectoriesExist();

            if (!File.Exists(_paths.SettingsFilePath))
            {
                _logger.LogInformation("Plik settings.json nie istnieje, zwracam domyślną konfigurację.");
                return new AppSettings();
            }

            await using var stream = File.OpenRead(_paths.SettingsFilePath);
            var settings = await JsonSerializer.DeserializeAsync<AppSettings>(stream, JsonOptions, cancellationToken)
                .ConfigureAwait(false);

            if (settings is null)
            {
                _logger.LogWarning("Plik settings.json istnieje ale deserializacja zwróciła null. Reset do default.");
                return new AppSettings();
            }

            return settings;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Nie udało się odczytać settings.json. Używam domyślnej konfiguracji.");
            return new AppSettings();
        }
        finally
        {
            _diskLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        await _diskLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureDirectoriesExist();

            // Atomic write: serialize do temp, potem rename. Crash-safe.
            var tempPath = _paths.SettingsFilePath + ".tmp";

            await using (var stream = File.Create(tempPath))
            {
                await JsonSerializer.SerializeAsync(stream, settings, JsonOptions, cancellationToken)
                    .ConfigureAwait(false);
            }

            if (File.Exists(_paths.SettingsFilePath))
            {
                File.Replace(tempPath, _paths.SettingsFilePath, destinationBackupFileName: null);
            }
            else
            {
                File.Move(tempPath, _paths.SettingsFilePath);
            }

            _logger.LogDebug("Settings zapisane do {Path}.", _paths.SettingsFilePath);
        }
        finally
        {
            _diskLock.Release();
        }
    }
}
