// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;
using PolskiWhisperWin.Features.UI;
using PolskiWhisperWin.Onboarding;
using PolskiWhisperWin.Supporting;

namespace PolskiWhisperWin;

/// <summary>
/// WinUI 3 application root - mapping do macOS <c>PolskiWhisperApp</c> + <c>AppDelegate</c>.
/// </summary>
public partial class App : Application
{
    /// <summary>Globalny dostęp do Coordinator-a (jak singleton). Inicjalizowane w OnLaunched.</summary>
    public static AppCoordinator Coordinator { get; private set; } = null!;

    private MainWindow? _settingsWindow;
    private TrayIconController? _trayIconController;

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
            // Inicjalizacja DI + serwisów.
            Coordinator = await AppCoordinator.CreateAsync().ConfigureAwait(true);

            // Tray icon - z menu Start, Settings, About, Quit.
            _trayIconController = Coordinator.Services.GetRequiredService<TrayIconController>();
            _trayIconController.Initialize();

            // Onboarding pokazuje się tylko jeśli OnboardingCompleted == false.
            if (!Coordinator.Settings.OnboardingCompleted)
            {
                ShowOnboardingWindow();
            }
            else
            {
                // Quiet start - aplikacja idzie do tray, nie pokazuje okna.
                Coordinator.Logger.LogInformation("Aplikacja wystartowana. Czekam na hotkey w tray.");
            }

            // Hotkey monitor - global keyboard hooks.
            await Coordinator.StartHotkeyMonitorAsync().ConfigureAwait(true);

            // Background: load model Whisper (jeśli już pobrany - inaczej czeka aż user zacznie nagrywać).
            _ = Task.Run(async () =>
            {
                try
                {
                    await Coordinator.PreloadWhisperModelIfDownloadedAsync().ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    Coordinator.Logger.LogWarning(ex, "Preload modelu Whisper nieudany - załadujemy on-demand.");
                }
            });

            // Background: sprawdź aktualizacje (raz na 24h).
            _ = Task.Run(async () =>
            {
                try
                {
                    await Coordinator.CheckForUpdatesIfDueAsync().ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    Coordinator.Logger.LogWarning(ex, "Sprawdzenie aktualizacji nieudane.");
                }
            });
        }
        catch (Exception ex)
        {
            // Fallback - pokaż dialog błędu i zamknij.
            CrashHandler.HandleStartupFailure(ex);
            Exit();
        }
    }

    /// <summary>
    /// Pokazuje główne okno Settings (z 4 zakładkami). Wywoływane z tray "Ustawienia..."
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

    /// <summary>
    /// Pokazuje OnboardingWizard - 6 kroków first-run experience.
    /// </summary>
    public void ShowOnboardingWindow()
    {
        var wizard = new OnboardingWindow();
        wizard.Activate();
    }

    private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        Coordinator?.Logger?.LogCritical(e.Exception, "Unhandled exception w UI thread.");
        CrashHandler.LogToFile(e.Exception);

        // Nie ukrywamy - pozwalamy WinUI pokazać dialog defaultowy.
        e.Handled = false;
    }
}
