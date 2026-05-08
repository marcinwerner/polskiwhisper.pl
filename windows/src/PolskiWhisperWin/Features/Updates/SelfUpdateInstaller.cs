// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Diagnostics;
using System.IO;
using Microsoft.Extensions.Logging;

namespace PolskiWhisperWin.Features.Updates;

/// <summary>
/// One-click auto-update installer. Mapping z macOS <c>UpdateChecker.downloadAndInstall</c> (v0.1.5).
/// </summary>
/// <remarks>
/// <para>Strategia (Windows wariant): generujemy PowerShell skrypt w <c>%TEMP%</c>, spawn-ujemy go
/// i terminujemy current proces. Skrypt:</para>
/// <list type="number">
///   <item>Czeka aż MSI installer process skończy (lub aż current proces zniknie z Process List).</item>
///   <item>Uruchamia <c>msiexec /i installer.msi /quiet</c>.</item>
///   <item>Czeka aż msiexec skończy.</item>
///   <item>Uruchamia <c>PolskiWhisper.exe</c> z nowej lokalizacji.</item>
///   <item>Sprząta MSI z temp + sam się usuwa.</item>
/// </list>
/// </remarks>
public sealed class SelfUpdateInstaller
{
    private readonly ILogger<SelfUpdateInstaller> _logger;

    public SelfUpdateInstaller(ILogger<SelfUpdateInstaller> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Spawn installer skrypt w tle, terminate current proces.
    /// Wywołanie zazwyczaj nigdy nie wraca - process się zamyka.
    /// </summary>
    public void InstallAndRestart(string msiInstallerPath)
    {
        if (!File.Exists(msiInstallerPath))
        {
            throw new FileNotFoundException("Installer MSI nie istnieje.", msiInstallerPath);
        }

        var currentExePath = Process.GetCurrentProcess().MainModule?.FileName
                             ?? throw new InvalidOperationException("Nie udało się ustalić ścieżki do exe.");

        var currentDir = Path.GetDirectoryName(currentExePath)
                         ?? throw new InvalidOperationException("Nie udało się ustalić katalogu aplikacji.");

        var scriptPath = Path.Combine(Path.GetTempPath(), $"polskiwhisper-update-{Guid.NewGuid():N}.ps1");
        var logPath = Path.Combine(Path.GetTempPath(), "polskiwhisper-update.log");
        var pid = Process.GetCurrentProcess().Id;

        var script = GenerateInstallerScript(
            installerMsiPath: msiInstallerPath,
            originalAppPath: currentExePath,
            originalAppDir: currentDir,
            ownPid: pid,
            logPath: logPath);

        File.WriteAllText(scriptPath, script);
        _logger.LogInformation("Generowano installer script: {Path}.", scriptPath);

        // Uruchom PowerShell w tle, NIE czekaj.
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{scriptPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        };

        Process.Start(startInfo);
        _logger.LogInformation("Installer script wystartowany. Aplikacja zaraz się zamknie.");

        // Daj chwilę na log + child process spawn.
        System.Threading.Thread.Sleep(500);

        // Terminate current proces - script się dobrze obsłuży gdy zniknie.
        Environment.Exit(0);
    }

    private static string GenerateInstallerScript(
        string installerMsiPath,
        string originalAppPath,
        string originalAppDir,
        int ownPid,
        string logPath)
    {
        // PowerShell skrypt - czyta proces ID, czeka aż zniknie, uruchamia msiexec.
        // UWAGA: używamy single quotes aby uniknąć escaping interpolacji.
        return $@"# PolskiWhisper auto-update installer script
# Generated: {DateTime.UtcNow:o}

$logPath = '{logPath}'
$installer = '{installerMsiPath}'
$origExe = '{originalAppPath}'
$origDir = '{originalAppDir}'
$ownPid = {ownPid}

function Log($msg) {{
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logPath -Value ""[$ts] $msg"" -ErrorAction SilentlyContinue
}}

Log 'PolskiWhisper update started.'

# Czekaj aż original process zniknie (max 15s).
$timeout = 15
$elapsed = 0
while ($elapsed -lt $timeout) {{
    try {{
        $proc = Get-Process -Id $ownPid -ErrorAction Stop
        Start-Sleep -Milliseconds 500
        $elapsed += 0.5
    }} catch {{
        Log 'Original process exited.'
        break
    }}
}}

# Uruchom MSI quiet install.
Log ""Uruchamiam msiexec /i $installer""
$msi = Start-Process -FilePath 'msiexec.exe' -ArgumentList ""/i"", ""`""$installer`"""", '/quiet', '/norestart' -Wait -PassThru
$exit = $msi.ExitCode
Log ""msiexec wyszedł z kodem $exit""

if ($exit -eq 0 -or $exit -eq 3010) {{
    # 0 = success, 3010 = restart pending - oba OK.
    Log 'Install OK, uruchamiam aplikację...'
    if (Test-Path $origExe) {{
        Start-Process -FilePath $origExe
    }} else {{
        # MSI mogło zmienić instalacyjny path - spróbuj %ProgramFiles%
        $alt = Join-Path $env:ProgramFiles 'PolskiWhisper\PolskiWhisper.exe'
        if (Test-Path $alt) {{
            Start-Process -FilePath $alt
        }} else {{
            Log 'Nie znaleziono PolskiWhisper.exe po install.'
        }}
    }}
}} else {{
    Log ""Install nieudany (kod $exit). Skip restart.""
}}

# Sprzątanie.
Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue
Remove-Item -Path $PSCommandPath -Force -ErrorAction SilentlyContinue
Log 'Update done.'
";
    }
}
