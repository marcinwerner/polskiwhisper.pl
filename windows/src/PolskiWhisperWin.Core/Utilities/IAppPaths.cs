// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Utilities;

/// <summary>
/// Centralne źródło ścieżek per-user. Wszystkie pliki aplikacji żyją pod
/// <c>%LOCALAPPDATA%\PolskiWhisper\</c>.
/// Interfejs umożliwia testy (mockowane temp directory).
/// </summary>
public interface IAppPaths
{
    /// <summary>Główny katalog danych aplikacji (np. <c>C:\Users\Marcin\AppData\Local\PolskiWhisper</c>).</summary>
    string AppDataDirectory { get; }

    /// <summary>Plik settings.json z konfiguracją aplikacji.</summary>
    string SettingsFilePath { get; }

    /// <summary>Plik SQLite z słownikiem (Find &amp; Replace rules).</summary>
    string VocabularyDatabasePath { get; }

    /// <summary>Katalog z modelami Whisper (.bin).</summary>
    string ModelsDirectory { get; }

    /// <summary>Katalog na temp WAV podczas nagrywania.</summary>
    string TempAudioDirectory { get; }

    /// <summary>Katalog na logi aplikacji (Serilog rolling files).</summary>
    string LogsDirectory { get; }

    /// <summary>Wymusza istnienie wszystkich katalogów (mkdir -p).</summary>
    void EnsureDirectoriesExist();
}
