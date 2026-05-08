// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;
using PolskiWhisperWin.Features.UI;
using PolskiWhisperWin.Supporting;

namespace PolskiWhisperWin;

/// <summary>
/// WinUI 3 application root. Mapping z macOS <c>PolskiWhisperApp</c> + <c>AppDelegate</c>.
/// </summary>
/// <remarks>
/// v0.1.0: placeholder UI - wszystkie complex pages są tymczasowo wyłączone w csproj.
/// Aktywuj je przez usunięcie odpowiednich <c>&lt;Page Remove&gt;</c> + <c>&lt;Compile Remove&gt;</c>.
/// </remarks>
public partial class App : Application
{
    /// <summary>Globalny dostęp do Coordinator-a (jak singleton).</summary>
    public static AppCoordinator Coordinator { get; private set; } = null!;

    private MainWindow? _settingsWindow;

    public App()
    {
        InitializeComponent();
        UnhandledException += OnUnhandledException;
    }

    /// <inheritdoc/>
    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            // Inicjalizacja DI + serwisów (Core + audio + paste + hotkey).
            Coordinator = await AppCoordinator.CreateAsync().ConfigureAwait(true);

            // Pokaż MainWindow placeholder.
            ShowSettingsWindow();

            // Hotkey monitor (background).
            await Coordinator.StartHotkeyMonitorAsync().ConfigureAwait(true);

            Coordinator.Logger.LogInformation("PolskiWhisper Windows v0.1.0 wystartowany. UI placeholder.");
        }
        catch (Exception ex)
        {
            CrashHandler.HandleStartupFailure(ex);
            Exit();
        }
    }

    /// <summary>
    /// Pokazuje główne okno (placeholder w v0.1.0).
    /// </summary>
    public void ShowSettingsWindow()
    {
        if (_settingsWindow is null || _settingsWindow.Content is null)
        {
            _settingsWindow = new MainWindow();
        }

        _settingsWindow.Activate();
        _settingsWindow.BringToFront();
    }

    private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        Coordinator?.Logger?.LogCritical(e.Exception, "Unhandled exception w UI thread.");
        CrashHandler.LogToFile(e.Exception);
        e.Handled = false;
    }
}
