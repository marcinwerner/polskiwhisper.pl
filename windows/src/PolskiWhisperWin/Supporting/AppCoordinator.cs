// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Serilog;
using PolskiWhisperWin.Core.Models;
using ILogger = Microsoft.Extensions.Logging.ILogger;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Core.Utilities;
using PolskiWhisperWin.Features.Dictation;
using PolskiWhisperWin.Features.UI;
using PolskiWhisperWin.Features.Updates;
using PolskiWhisperWin.Hotkey;

namespace PolskiWhisperWin.Supporting;

/// <summary>
/// Centralny coordinator - DI container + global state aplikacji.
/// Mapping 1:1 do macOS <c>AppCoordinator</c> singleton.
/// </summary>
public sealed class AppCoordinator
{
    /// <summary>Container Microsoft.Extensions.DependencyInjection.</summary>
    public IServiceProvider Services { get; }

    /// <summary>Logger - ostry handle do common-use logger w callsites.</summary>
    public ILogger Logger { get; }

    /// <summary>Aktualne settings (live - update przy save).</summary>
    public AppSettings Settings { get; private set; } = new();

    /// <summary>DictationEngine - centralny orchestrator nagrywania.</summary>
    public DictationEngine DictationEngine { get; }

    /// <summary>HotkeyMonitor - global keyboard hooks (SharpHook).</summary>
    public HotkeyMonitor HotkeyMonitor { get; }

    private AppCoordinator(IServiceProvider services)
    {
        Services = services;
        Logger = services.GetRequiredService<ILoggerFactory>().CreateLogger("PolskiWhisperWin");
        DictationEngine = services.GetRequiredService<DictationEngine>();
        HotkeyMonitor = services.GetRequiredService<HotkeyMonitor>();
    }

    /// <summary>
    /// Buduje DI container i inicjalizuje wszystkie serwisy.
    /// </summary>
    public static async Task<AppCoordinator> CreateAsync(CancellationToken cancellationToken = default)
    {
        // 1) Setup ścieżek + logging.
        var paths = new AppPaths();
        paths.EnsureDirectoriesExist();
        SerilogConfiguration.Initialize(paths);

        // 2) Build DI services.
        var services = new ServiceCollection();
        ConfigureServices(services, paths);
        var provider = services.BuildServiceProvider();

        // 3) Inicjalizuj cocoordinator.
        var coordinator = new AppCoordinator(provider);
        coordinator.Logger.LogInformation("AppCoordinator: rozpoczynam inicjalizację.");

        // 4) Wczytaj settings z dysku.
        var settingsStore = provider.GetRequiredService<ISettingsStore>();
        coordinator.Settings = await settingsStore.LoadAsync(cancellationToken).ConfigureAwait(false);
        coordinator.Logger.LogInformation("Settings załadowane.");

        // 5) Inicjalizacja vocabulary store (SQLite + migracje).
        var vocabularyStore = provider.GetRequiredService<IVocabularyStore>();
        await vocabularyStore.InitializeAsync(cancellationToken).ConfigureAwait(false);

        coordinator.Logger.LogInformation("AppCoordinator: gotowy.");
        return coordinator;
    }

    /// <summary>
    /// Zapisuje settings do dysku i propaguje zmiany do live properties.
    /// </summary>
    public async Task UpdateSettingsAsync(AppSettings updated, CancellationToken cancellationToken = default)
    {
        var store = Services.GetRequiredService<ISettingsStore>();
        await store.SaveAsync(updated, cancellationToken).ConfigureAwait(false);
        Settings = updated;
        SettingsChanged?.Invoke(this, updated);
    }

    /// <summary>Event - settings zmienione. Subscribed by tabs.</summary>
    public event EventHandler<AppSettings>? SettingsChanged;

    /// <summary>
    /// Rejestruje hotkey listening.
    /// </summary>
    public Task StartHotkeyMonitorAsync()
    {
        HotkeyMonitor.HotkeyTapped += OnHotkeyTapped;
        HotkeyMonitor.HotkeyHoldStart += OnHotkeyHoldStart;
        HotkeyMonitor.HotkeyHoldEnd += OnHotkeyHoldEnd;
        HotkeyMonitor.EscapePressed += OnEscapePressed;

        return HotkeyMonitor.StartAsync(Settings.HotkeyVirtualKeyCode);
    }

    private async void OnHotkeyTapped(object? sender, EventArgs e)
    {
        try
        {
            if (Settings.HotkeyMode != HotkeyMode.Toggle) return;

            if (DictationEngine.Phase == AppPhase.Idle)
            {
                await DictationEngine.StartDictationAsync().ConfigureAwait(false);
            }
            else if (DictationEngine.Phase == AppPhase.Recording)
            {
                await DictationEngine.StopDictationAsync().ConfigureAwait(false);
            }
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Hotkey tap handler failed.");
        }
    }

    private async void OnHotkeyHoldStart(object? sender, EventArgs e)
    {
        try
        {
            if (Settings.HotkeyMode != HotkeyMode.Hold) return;
            await DictationEngine.StartDictationAsync().ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Hotkey hold-start handler failed.");
        }
    }

    private async void OnHotkeyHoldEnd(object? sender, EventArgs e)
    {
        try
        {
            if (Settings.HotkeyMode != HotkeyMode.Hold) return;
            await DictationEngine.StopDictationAsync().ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Hotkey hold-end handler failed.");
        }
    }

    private async void OnEscapePressed(object? sender, EventArgs e)
    {
        try
        {
            await DictationEngine.CancelDictationAsync().ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "ESC cancel handler failed.");
        }
    }

    /// <summary>
    /// Jeśli wybrany model Whisper jest już pobrany, ładuje go w tle.
    /// </summary>
    public async Task PreloadWhisperModelIfDownloadedAsync()
    {
        var paths = Services.GetRequiredService<IAppPaths>();
        var modelPath = System.IO.Path.Combine(
            paths.ModelsDirectory,
            $"{Settings.SelectedWhisperModelId}.bin");

        if (!System.IO.File.Exists(modelPath))
        {
            Logger.LogInformation("Model {ModelId} nie jest pobrany. Pominę preload.", Settings.SelectedWhisperModelId);
            return;
        }

        var whisper = Services.GetRequiredService<IWhisperService>();
        await whisper.LoadModelAsync(Settings.SelectedWhisperModelId).ConfigureAwait(false);
    }

    /// <summary>
    /// Sprawdza aktualizacje (jeśli minęło >24h od ostatniego sprawdzenia).
    /// </summary>
    public async Task CheckForUpdatesIfDueAsync()
    {
        if (Settings.LastUpdateCheck is { } last)
        {
            if (DateTimeOffset.UtcNow - last < TimeSpan.FromHours(24))
            {
                Logger.LogDebug("Update check pominięty - ostatni był < 24h temu.");
                return;
            }
        }

        var checker = Services.GetRequiredService<IUpdateChecker>();
        var currentVersion = typeof(AppCoordinator).Assembly.GetName().Version?.ToString(3) ?? "0.0.0";

        var update = await checker.CheckForUpdateAsync(currentVersion).ConfigureAwait(false);

        Settings.LastUpdateCheck = DateTimeOffset.UtcNow;
        await Services.GetRequiredService<ISettingsStore>().SaveAsync(Settings).ConfigureAwait(false);

        if (update is { IsNewer: true })
        {
            Logger.LogInformation("Dostępna nowa wersja {Version}.", update.LatestVersion);
            try
            {
                Services.GetRequiredService<NotificationDispatcher>().ShowUpdateAvailable(update);
            }
            catch (Exception ex)
            {
                Logger.LogWarning(ex, "NotificationDispatcher.ShowUpdateAvailable nieudane.");
            }
        }
    }

    private static void ConfigureServices(IServiceCollection services, IAppPaths paths)
    {
        // Logging - Serilog provider.
        services.AddLogging(builder =>
        {
            builder.SetMinimumLevel(LogLevel.Debug);
            builder.AddSerilog(dispose: true);
        });

        // Paths.
        services.AddSingleton<IAppPaths>(paths);

        // HttpClient pool dla wszystkich serwisów co go potrzebują.
        services.AddSingleton<HttpClient>(sp => new HttpClient { Timeout = TimeSpan.FromMinutes(20) });

        // Storage.
        services.AddSingleton<ISettingsStore, JsonSettingsStore>();
        services.AddSingleton<IVocabularyStore, SqliteVocabularyStore>();

        // Core services.
        services.AddSingleton<VocabularyProcessor>();
        services.AddSingleton<WhisperHallucinationFilter>();
        services.AddSingleton<IWhisperService, WhisperService>();
        services.AddSingleton<IUpdateChecker, UpdateChecker>();

        // Windows-specific implementations.
        services.AddSingleton<IAudioRecorder, NAudioRecorder>();
        services.AddSingleton<IPasteService, ClipboardPasteService>();
        services.AddSingleton<HotkeyMonitor>();
        services.AddSingleton<DuplicateAppFinder>();
        services.AddSingleton<LaunchAtLoginManager>();
        services.AddSingleton<SelfUpdateInstaller>();
        services.AddSingleton<SoundService>();
        services.AddSingleton<NotificationDispatcher>();
        services.AddSingleton<TrayIconController>();

        // Orchestrator.
        services.AddSingleton<DictationEngine>();
    }
}
