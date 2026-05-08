// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using PolskiWhisperWin.Supporting;

namespace PolskiWhisperWin;

/// <summary>
/// Entry point unpackaged WinUI 3 aplikacji.
/// </summary>
/// <remarks>
/// <para>Single-instance check przez named Mutex - jeśli inny PolskiWhisper już chodzi,
/// terminujemy ten proces (lub można forward arguments do running instance).</para>
/// <para>WinUI 3 unpackaged wymaga manualnej inicjalizacji <c>DispatcherQueueSynchronizationContext</c>
/// i <c>XamlCheckProcessRequirements</c>.</para>
/// </remarks>
public static class Program
{
    /// <summary>Mutex name dla single-instance enforcement.</summary>
    private const string SingleInstanceMutexName = "Global\\PolskiWhisper-SingleInstance-{B7AB12CD-3344-5566-7788-99AABBCCDDEE}";

    [STAThread]
    public static int Main(string[] args)
    {
        // Single-instance check - jeśli inny już chodzi, kończymy.
        var mutex = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out var createdNew);
        if (!createdNew)
        {
            // Inny PolskiWhisper już działa.
            // TODO: w przyszłości wysłać IPC sygnał aby pokazać Settings window.
            Console.Error.WriteLine("PolskiWhisper jest już uruchomiony. Sprawdź ikonę w systemowym pasku zadań.");
            return 1;
        }

        try
        {
            // WinUI 3 unpackaged needs ComWrappers init.
            ComWrappersSupport.InitializeComWrappers();

            XamlCheckProcessRequirements();

            // Globalny exception handler - zapisuje crash log do %LOCALAPPDATA%\PolskiWhisper\logs\.
            CrashHandler.Install();

            Application.Start(p =>
            {
                var context = new DispatcherQueueSynchronizationContext(
                    DispatcherQueue.GetForCurrentThread());
                SynchronizationContext.SetSynchronizationContext(context);
                _ = new App();
            });

            return 0;
        }
        finally
        {
            mutex.ReleaseMutex();
            mutex.Dispose();
        }
    }

    [DllImport("Microsoft.ui.xaml.dll", CallingConvention = CallingConvention.StdCall)]
    private static extern void XamlCheckProcessRequirements();
}

/// <summary>
/// Helper dla ComWrappers init w unpackaged WinUI 3.
/// </summary>
internal static class ComWrappersSupport
{
    public static void InitializeComWrappers()
    {
        // No-op placeholder - WindowsAppSDK 1.5+ inicjalizuje internal.
        // Jeśli kiedyś będziemy używać WinRT.ComWrappersSupport.Initialize, dodać tutaj.
    }
}
