// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Reflection;
using Microsoft.UI.Xaml;

namespace PolskiWhisperWin.Features.UI;

/// <summary>
/// Główne okno (placeholder w v0.1.0).
/// W kolejnych iteracjach: 4 zakładki Settings (Ogólne, Whisper, Słownik, O programie).
/// </summary>
public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Title = "PolskiWhisper";

        var version = Assembly.GetExecutingAssembly().GetName().Version;
        if (version is not null)
        {
            VersionLabel.Text = $"v{version.Major}.{version.Minor}.{version.Build}";
        }
    }

    /// <summary>Wymuś okno na wierzch (z tray).</summary>
    public void BringToFront() => Activate();
}
