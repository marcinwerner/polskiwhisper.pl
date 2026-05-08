// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Utilities;

/// <summary>
/// Domyślna implementacja <see cref="IAppPaths"/> - używa <see cref="Environment.SpecialFolder.LocalApplicationData"/>.
/// </summary>
public sealed class AppPaths : IAppPaths
{
    private const string AppFolderName = "PolskiWhisper";

    public string AppDataDirectory { get; }
    public string SettingsFilePath { get; }
    public string VocabularyDatabasePath { get; }
    public string ModelsDirectory { get; }
    public string TempAudioDirectory { get; }
    public string LogsDirectory { get; }

    /// <summary>
    /// Konstruktor używający <c>%LOCALAPPDATA%\PolskiWhisper</c>.
    /// </summary>
    public AppPaths() : this(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData))
    {
    }

    /// <summary>
    /// Konstruktor z customowym root - przydatny w testach (temp folder).
    /// </summary>
    public AppPaths(string rootDirectory)
    {
        AppDataDirectory = Path.Combine(rootDirectory, AppFolderName);
        SettingsFilePath = Path.Combine(AppDataDirectory, "settings.json");
        VocabularyDatabasePath = Path.Combine(AppDataDirectory, "vocabulary.db");
        ModelsDirectory = Path.Combine(AppDataDirectory, "models");
        TempAudioDirectory = Path.Combine(AppDataDirectory, "temp");
        LogsDirectory = Path.Combine(AppDataDirectory, "logs");
    }

    public void EnsureDirectoriesExist()
    {
        Directory.CreateDirectory(AppDataDirectory);
        Directory.CreateDirectory(ModelsDirectory);
        Directory.CreateDirectory(TempAudioDirectory);
        Directory.CreateDirectory(LogsDirectory);
    }
}
