// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Reflection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Features.UI.Pages;

namespace PolskiWhisperWin.Features.UI;

/// <summary>
/// Główne okno Settings - mapping z macOS <c>MainWindow</c>. 4 zakładki:
/// Ogólne, Whisper, Słownik, O programie.
/// </summary>
public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        // Update title bar - show version z assembly.
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        if (version is not null)
        {
            VersionLabel.Text = $"v{version.Major}.{version.Minor}.{version.Build}";
        }

        Title = "PolskiWhisper - Ustawienia";

        // Default page: General.
        ContentFrame.Navigate(typeof(GeneralSettingsPage));
    }

    /// <summary>
    /// Wymuś okno na wierzch - wywoływane z tray (lewy klik).
    /// </summary>
    public void BringToFront()
    {
        Activate();
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item) return;

        var pageType = item.Tag?.ToString() switch
        {
            "general" => typeof(GeneralSettingsPage),
            "whisper" => typeof(WhisperSettingsPage),
            "vocabulary" => typeof(VocabularySettingsPage),
            "about" => typeof(AboutPage),
            _ => null
        };

        if (pageType is not null)
        {
            ContentFrame.Navigate(pageType);
        }
    }
}
