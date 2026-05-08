// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.IO;
using PolskiWhisperWin.Core.Utilities;
using Serilog;
using Serilog.Events;

namespace PolskiWhisperWin.Supporting;

/// <summary>
/// Konfiguracja Serilog - rolling file w <c>%LOCALAPPDATA%\PolskiWhisper\logs\</c>
/// + Debug output w VS.
/// </summary>
internal static class SerilogConfiguration
{
    public static void Initialize(IAppPaths paths)
    {
        var logFile = Path.Combine(paths.LogsDirectory, "polskiwhisper-.log");

        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Debug()
            .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
            .MinimumLevel.Override("System", LogEventLevel.Warning)
            .Enrich.WithThreadId()
            .Enrich.WithProperty("App", "PolskiWhisperWin")
            .WriteTo.Debug(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext}: {Message:lj}{NewLine}{Exception}")
            .WriteTo.File(
                logFile,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 7,
                fileSizeLimitBytes: 10 * 1024 * 1024,
                rollOnFileSizeLimit: true,
                outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff} {Level:u3}] [{ThreadId}] {SourceContext}: {Message:lj}{NewLine}{Exception}")
            .CreateLogger();

        Log.Information("Serilog logger zainicjalizowany. Pliki w {LogsDir}.", paths.LogsDirectory);
    }
}
