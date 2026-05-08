// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Diagnostics;
using System.IO;
using H.NotifyIcon;
using H.NotifyIcon.Core;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;

namespace PolskiWhisperWin.Features.UI;

/// <summary>
/// System tray icon - mapping z macOS <c>MenuBarController</c>.
/// Używa H.NotifyIcon (modern wrapper na Win32 Shell_NotifyIcon, kompatybilny z WinUI 3).
/// </summary>
public sealed class TrayIconController : IDisposable
{
    private readonly DictationEngine _dictationEngine;
    private readonly ILogger<TrayIconController> _logger;
    private TrayIconWithContextMenu? _trayIcon;
    private PopupMenuItem? _statusMenuItem;
    private PopupMenuItem? _toggleMenuItem;

    public TrayIconController(DictationEngine dictationEngine, ILogger<TrayIconController> logger)
    {
        _dictationEngine = dictationEngine;
        _logger = logger;
    }

    /// <summary>
    /// Inicjalizuj tray icon. Subskrybuje events z DictationEngine aby update'ować ikonę i status.
    /// </summary>
    public void Initialize()
    {
        try
        {
            var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "TrayIcon.ico");
            var iconHandle = LoadIcon(iconPath);

            _trayIcon = new TrayIconWithContextMenu
            {
                Icon = iconHandle,
                ToolTip = "PolskiWhisper - dyktowanie głosowe",
                ContextMenu = BuildContextMenu()
            };

            _trayIcon.MessageWindow.MouseEventReceived += (_, e) =>
            {
                if (e.MouseEvent == MouseEvent.IconLeftMouseUp)
                {
                    OnTrayLeftClick();
                }
            };

            _trayIcon.Create();
            _dictationEngine.PhaseChanged += OnPhaseChanged;

            _logger.LogInformation("Tray icon zainicjalizowany.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Inicjalizacja tray icon nieudana.");
        }
    }

    private PopupMenu BuildContextMenu()
    {
        _statusMenuItem = new PopupMenuItem("Stan: Gotowy") { Enabled = false };

        _toggleMenuItem = new PopupMenuItem("Rozpocznij dyktowanie", (_, _) => OnToggleDictation());

        var settingsItem = new PopupMenuItem("Ustawienia...", (_, _) => OnOpenSettings());
        var aboutItem = new PopupMenuItem("O programie", (_, _) => OnAbout());
        var quitItem = new PopupMenuItem("Zakończ", (_, _) => OnQuit());

        return new PopupMenu
        {
            Items =
            {
                _statusMenuItem,
                new PopupMenuSeparator(),
                _toggleMenuItem,
                new PopupMenuSeparator(),
                settingsItem,
                aboutItem,
                new PopupMenuSeparator(),
                quitItem
            }
        };
    }

    private void OnPhaseChanged(object? sender, AppPhase phase)
    {
        if (_statusMenuItem is null || _toggleMenuItem is null) return;

        var (statusText, toggleText) = phase switch
        {
            AppPhase.Idle => ("Stan: Gotowy", "Rozpocznij dyktowanie"),
            AppPhase.Recording => ("Stan: Nagrywanie...", "Zatrzymaj nagrywanie"),
            AppPhase.Processing => ("Stan: Przetwarzanie...", "Anuluj"),
            AppPhase.Pasting => ("Stan: Wklejanie...", "Anuluj"),
            AppPhase.Completed => ("Stan: Gotowe ✓", "Rozpocznij dyktowanie"),
            AppPhase.Error => ("Stan: Błąd", "Rozpocznij dyktowanie"),
            _ => ("Stan: ?", "Rozpocznij dyktowanie")
        };

        _statusMenuItem.Text = statusText;
        _toggleMenuItem.Text = toggleText;
    }

    private async void OnToggleDictation()
    {
        if (_dictationEngine.Phase == AppPhase.Idle)
        {
            await _dictationEngine.StartDictationAsync().ConfigureAwait(false);
        }
        else if (_dictationEngine.Phase == AppPhase.Recording)
        {
            await _dictationEngine.StopDictationAsync().ConfigureAwait(false);
        }
    }

    private void OnTrayLeftClick()
    {
        // Lewy klik = pokaż Settings (jak w macOS Dock).
        OnOpenSettings();
    }

    private void OnOpenSettings()
    {
        try
        {
            App.Coordinator.Logger.LogDebug("Tray: otwórz Settings");
            (Microsoft.UI.Xaml.Application.Current as App)?.ShowSettingsWindow();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Open settings nieudane.");
        }
    }

    private void OnAbout()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://github.com/marcinwerner/polskiwhisper.pl",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Nie udało się otworzyć linku o programie.");
        }
    }

    private void OnQuit()
    {
        _logger.LogInformation("Tray: użytkownik wybrał Zakończ.");
        Microsoft.UI.Xaml.Application.Current.Exit();
    }

    /// <summary>
    /// Wczytuje ikonę .ico - jeśli plik nie istnieje, używa default systemowej.
    /// </summary>
    private static System.Drawing.Icon LoadIcon(string path)
    {
        try
        {
            if (File.Exists(path))
                return new System.Drawing.Icon(path);
        }
        catch
        {
            // fallback poniżej
        }

        // Fallback: default app icon.
        return System.Drawing.SystemIcons.Application;
    }

    public void Dispose()
    {
        _dictationEngine.PhaseChanged -= OnPhaseChanged;
        _trayIcon?.Dispose();
    }
}
