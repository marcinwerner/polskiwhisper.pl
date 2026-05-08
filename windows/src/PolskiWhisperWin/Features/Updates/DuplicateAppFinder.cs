// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace PolskiWhisperWin.Features.Updates;

/// <summary>
/// Znajdowanie kopii PolskiWhisper.exe poza standardową lokalizacją instalacji.
/// Mapping z macOS <c>DuplicateAppFinder</c> (v0.1.5).
/// </summary>
/// <remarks>
/// Skanowane lokalizacje:
/// <list type="bullet">
///   <item><c>%USERPROFILE%\Desktop</c></item>
///   <item><c>%USERPROFILE%\Downloads</c></item>
///   <item><c>%USERPROFILE%\Documents</c></item>
///   <item><c>%LOCALAPPDATA%\Programs</c></item>
/// </list>
/// </remarks>
public sealed class DuplicateAppFinder
{
    private const string AppExecutableName = "PolskiWhisper.exe";

    private readonly ILogger<DuplicateAppFinder> _logger;

    public DuplicateAppFinder(ILogger<DuplicateAppFinder> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Skanuje typowe lokalizacje. Pomija ścieżkę aktualnie uruchomionej aplikacji.
    /// </summary>
    public async Task<IReadOnlyList<DuplicateApp>> FindDuplicatesAsync()
    {
        var ownPath = Process.GetCurrentProcess().MainModule?.FileName;
        var ownDirectory = ownPath is null ? null : Path.GetDirectoryName(ownPath);

        var locations = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"),
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs"),
        };

        var duplicates = new List<DuplicateApp>();

        await Task.Run(() =>
        {
            foreach (var location in locations)
            {
                if (string.IsNullOrEmpty(location) || !Directory.Exists(location)) continue;

                try
                {
                    foreach (var exe in Directory.EnumerateFiles(
                                 location,
                                 AppExecutableName,
                                 new EnumerationOptions
                                 {
                                     RecurseSubdirectories = true,
                                     IgnoreInaccessible = true,
                                     MaxRecursionDepth = 4
                                 }))
                    {
                        var dir = Path.GetDirectoryName(exe);
                        if (dir is null) continue;
                        if (string.Equals(dir, ownDirectory, StringComparison.OrdinalIgnoreCase)) continue;

                        try
                        {
                            var info = new FileInfo(exe);
                            duplicates.Add(new DuplicateApp(
                                Path: exe,
                                SizeBytes: info.Length,
                                LastModified: info.LastWriteTime));
                        }
                        catch (Exception ex)
                        {
                            _logger.LogDebug(ex, "Pominięto {Path} (dostęp).", exe);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogDebug(ex, "Skan {Location} nieudany.", location);
                }
            }
        }).ConfigureAwait(false);

        return duplicates;
    }

    /// <summary>
    /// Przenosi <paramref name="duplicate"/> do Kosza.
    /// </summary>
    public bool MoveToTrash(DuplicateApp duplicate)
    {
        try
        {
            // .NET nie ma natywnego wsparcia recycle bin - używamy Microsoft.VisualBasic.FileIO.
            // Aby uniknąć dependency, używamy SHFileOperation Win32.
            return ShellMoveToRecycleBin(duplicate.Path);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Move to trash nieudane: {Path}.", duplicate.Path);
            return false;
        }
    }

    [System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto)]
    private static extern int SHFileOperation(ref SHFILEOPSTRUCT FileOp);

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
    private struct SHFILEOPSTRUCT
    {
        public IntPtr hwnd;
        public uint wFunc;
        [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)]
        public string pFrom;
        [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)]
        public string? pTo;
        public ushort fFlags;
        public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)]
        public string? lpszProgressTitle;
    }

    private const uint FO_DELETE = 0x0003;
    private const ushort FOF_ALLOWUNDO = 0x0040;
    private const ushort FOF_NOCONFIRMATION = 0x0010;
    private const ushort FOF_SILENT = 0x0004;

    private static bool ShellMoveToRecycleBin(string path)
    {
        var op = new SHFILEOPSTRUCT
        {
            wFunc = FO_DELETE,
            pFrom = path + "\0\0", // Double-null terminated string.
            fFlags = (ushort)(FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT)
        };

        return SHFileOperation(ref op) == 0;
    }
}

/// <summary>Znaleziona kopia aplikacji.</summary>
/// <param name="Path">Pełna ścieżka do exe.</param>
/// <param name="SizeBytes">Rozmiar pliku.</param>
/// <param name="LastModified">Data ostatniej modyfikacji.</param>
public sealed record DuplicateApp(string Path, long SizeBytes, DateTime LastModified);
