// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Diagnostics;
using Microsoft.Extensions.Logging;
using Microsoft.Win32;

namespace PolskiWhisperWin.Supporting;

/// <summary>
/// Zarządza autostart aplikacji - wpis w
/// <c>HKCU\Software\Microsoft\Windows\CurrentVersion\Run</c>.
/// </summary>
/// <remarks>
/// Run key wymaga zwykłych user permissions (nie potrzeba UAC).
/// Mapping z macOS <c>LaunchAtLogin</c> NSPM API.
/// </remarks>
public sealed class LaunchAtLoginManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "PolskiWhisper";

    private readonly ILogger<LaunchAtLoginManager> _logger;

    public LaunchAtLoginManager(ILogger<LaunchAtLoginManager> logger)
    {
        _logger = logger;
    }

    /// <summary>Czy aplikacja jest skonfigurowana do startu przy logowaniu.</summary>
    public bool IsEnabled
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
                if (key is null) return false;

                var value = key.GetValue(AppName) as string;
                return !string.IsNullOrEmpty(value);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Nie udało się odczytać autostart status.");
                return false;
            }
        }
    }

    /// <summary>Włącz autostart - zapisuje pełną ścieżkę do exe w Run.</summary>
    public bool Enable()
    {
        try
        {
            var exePath = Process.GetCurrentProcess().MainModule?.FileName;
            if (string.IsNullOrEmpty(exePath))
            {
                _logger.LogWarning("Nie udało się ustalić ścieżki do exe.");
                return false;
            }

            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);
            key.SetValue(AppName, $"\"{exePath}\"", RegistryValueKind.String);

            _logger.LogInformation("Autostart włączony: {Path}.", exePath);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Włączenie autostart nieudane.");
            return false;
        }
    }

    /// <summary>Wyłącz autostart - usuwa wpis z Run.</summary>
    public bool Disable()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true);
            if (key is null) return true; // Klucz nie istnieje = wyłączone.

            if (key.GetValue(AppName) is not null)
            {
                key.DeleteValue(AppName, throwOnMissingValue: false);
                _logger.LogInformation("Autostart wyłączony.");
            }

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Wyłączenie autostart nieudane.");
            return false;
        }
    }

    /// <summary>Set bool wrapper - wygodne dla bindings w UI.</summary>
    public bool SetEnabled(bool enabled) => enabled ? Enable() : Disable();
}
