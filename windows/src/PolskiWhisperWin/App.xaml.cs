// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Features.UI;
using PolskiWhisperWin.Features.UI.Floating;
using PolskiWhisperWin.Onboarding;
using PolskiWhisperWin.Supporting;

namespace PolskiWhisperWin;

/// <summary>
/// WinUI 3 application root. Mapping z macOS <c>PolskiWhisperApp</c> + <c>AppDelegate</c>.
/// </summary>
/// <remarks>
/// Cykl życia:
/// 1. <see cref="OnLaunched"/> - inicjalizacja DI + serwisów (Core, audio, paste, hotkey).
/// 2. Jeśli pierwsze uruchomienie - <see cref="OnboardingWindow"/>; w przeciwnym razie <see cref="MainWindow"/>.
/// 3. Tray icon + FloatingDictationWindow (lifecycle z aplikacją).
/// 4. Hotkey monitor w tle, update check (24h), preload modelu Whisper.
/// </remarks>
public partial class App : Application
{
    /// <summary>Globalny dostęp do Coordinator-a (jak singleton).</summary>
    public static AppCoordinator Coordinator { get; private set; } = null!;

    private MainWindow? _settingsWindow;
    private OnboardingWindow? _onboardingWindow;
    private FloatingDictationWindow? _floatingWindow;
    private DispatcherQueue? _uiDispatcher;

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
            _uiDispatcher = DispatcherQueue.GetForCurrentThread();

            // Inicjalizacja DI + serwisów (Core + audio + paste + hotkey).
            Coordinator = await AppCoordinator.CreateAsync().ConfigureAwait(true);

            // Tray icon - widoczny od razu.
            try
            {
                var trayIcon = Coordinator.Services.GetRequiredService<TrayIconController>();
                trayIcon.Initialize();
            }
            catch (Exception ex)
            {
                Coordinator.Logger.LogWarning(ex, "Tray icon nieudane - aplikacja kontynuuje bez tray.");
            }

            // FloatingDictationWindow podlega DictationEngine.PhaseChanged.
            SetupFloatingDictationWindow();

            // First run: onboarding zamiast Settings.
            if (!Coordinator.Settings.OnboardingCompleted)
            {
                ShowOnboardingWindow();
            }
            else
            {
                ShowSettingsWindow();
            }

            // Hotkey monitor w tle.
            await Coordinator.StartHotkeyMonitorAsync().ConfigureAwait(true);

            // Update check (jeśli > 24h od ostatniego).
            _ = Task.Run(async () =>
            {
                try
                {
                    await Coordinator.CheckForUpdatesIfDueAsync();
                }
                catch (Exception ex)
                {
                    Coordinator.Logger.LogWarning(ex, "Update check nieudane.");
                }
            });

            // Preload modelu Whisper (jeśli pobrany).
            _ = Task.Run(async () =>
            {
                try
                {
                    await Coordinator.PreloadWhisperModelIfDownloadedAsync();
                }
                catch (Exception ex)
                {
                    Coordinator.Logger.LogWarning(ex, "Preload modelu Whisper nieudane.");
                }
            });

            Coordinator.Logger.LogInformation("PolskiWhisper Windows wystartowany.");
        }
        catch (Exception ex)
        {
            CrashHandler.HandleStartupFailure(ex);
            Exit();
        }
    }

    /// <summary>
    /// Tworzy FloatingDictationWindow na nowo i podpina go do DictationEngine.PhaseChanged.
    /// Window jest re-created przy każdym Recording start (Show), ukryty przy Idle.
    /// </summary>
    private void SetupFloatingDictationWindow()
    {
        Coordinator.DictationEngine.PhaseChanged += (_, phase) =>
        {
            _uiDispatcher?.TryEnqueue(() =>
            {
                if (phase == AppPhase.Recording && _floatingWindow is null)
                {
                    var audioRecorder = Coordinator.Services.GetRequiredService<IAudioRecorder>();
                    _floatingWindow = new FloatingDictationWindow(Coordinator.DictationEngine, audioRecorder);
                    _floatingWindow.Closed += (_, _) => _floatingWindow = null;
                    _floatingWindow.Activate();
                }
                else if (phase == AppPhase.Idle && _floatingWindow is not null)
                {
                    _floatingWindow.HideWindow();
                }
            });
        };
    }

    /// <summary>
    /// Pokazuje główne okno Settings (4 zakładki).
    /// </summary>
    public void ShowSettingsWindow()
    {
        if (_settingsWindow is null)
        {
            _settingsWindow = new MainWindow();
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }

        _settingsWindow.Activate();
        _settingsWindow.BringToFront();
    }

    /// <summary>
    /// Pokazuje OnboardingWindow (first-run flow).
    /// </summary>
    public void ShowOnboardingWindow()
    {
        if (_onboardingWindow is null)
        {
            _onboardingWindow = new OnboardingWindow();
            _onboardingWindow.Closed += (_, _) =>
            {
                _onboardingWindow = null;
                // Po onboardingu otwórz MainWindow.
                if (Coordinator.Settings.OnboardingCompleted)
                {
                    ShowSettingsWindow();
                }
            };
        }

        _onboardingWindow.Activate();
    }

    private void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        Coordinator?.Logger?.LogCritical(e.Exception, "Unhandled exception w UI thread.");
        CrashHandler.LogToFile(e.Exception);
        e.Handled = false;
    }
}
