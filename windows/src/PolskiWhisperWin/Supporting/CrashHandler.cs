// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.IO;
using Serilog;

namespace PolskiWhisperWin.Supporting;

/// <summary>
/// Globalny exception handler. Loguje wszystkie unhandled exceptions do pliku +
/// pokazuje friendly dialog gdy startup fail.
/// </summary>
internal static class CrashHandler
{
    public static void Install()
    {
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
        {
            if (e.ExceptionObject is Exception ex)
            {
                LogToFile(ex);
            }
        };

        TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            LogToFile(e.Exception);
            e.SetObserved();
        };
    }

    public static void LogToFile(Exception ex)
    {
        try
        {
            Log.Logger?.Fatal(ex, "Unhandled exception.");
        }
        catch
        {
            // Last resort - log do %TEMP%.
            try
            {
                var tempLog = Path.Combine(Path.GetTempPath(), "polskiwhisper-crash.log");
                File.AppendAllText(tempLog,
                    $"[{DateTime.UtcNow:o}] {ex}{Environment.NewLine}{Environment.NewLine}");
            }
            catch
            {
                // Nothing more we can do.
            }
        }
    }

    public static void HandleStartupFailure(Exception ex)
    {
        LogToFile(ex);

        // Pokaż MessageBox z linkiem do logów. Używamy Win32 MessageBox - WinUI 3
        // może nie być jeszcze zainicjalizowany podczas startup failure.
        try
        {
            var message = $"PolskiWhisper nie mógł wystartować.\n\n{ex.Message}\n\n" +
                          $"Logi znajdują się w %LOCALAPPDATA%\\PolskiWhisper\\logs\\";
            MessageBoxW(IntPtr.Zero, message, "PolskiWhisper - błąd startu", 0x00000010);
        }
        catch
        {
            // Even MessageBox failed - nothing more we can do.
        }
    }

    [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);
}
