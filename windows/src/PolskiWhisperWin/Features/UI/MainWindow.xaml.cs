// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Reflection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Features.UI.Pages;

namespace PolskiWhisperWin.Features.UI;

/// <summary>
/// Główne okno Settings z 4 zakładkami: Ogólne, Whisper, Słownik, O programie.
/// </summary>
/// <remarks>
/// Mapping z macOS <c>SettingsView</c> (4 taby) - tutaj NavigationView z PaneDisplayMode="Top".
/// </remarks>
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

        // NavigationView jako FrameworkElement ma Loaded (Window nie ma).
        MainNav.Loaded += (_, _) =>
        {
            // Domyślnie pokazuje pierwszą zakładkę (Ogólne).
            if (MainNav.MenuItems.Count > 0 && MainNav.MenuItems[0] is NavigationViewItem firstItem)
            {
                MainNav.SelectedItem = firstItem;
            }
        };
    }

    private void MainNav_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item) return;
        var tag = item.Tag?.ToString();

        switch (tag)
        {
            case "general":
                ContentFrame.Navigate(typeof(GeneralSettingsPage));
                break;
            case "whisper":
                ContentFrame.Navigate(typeof(WhisperSettingsPage));
                break;
            case "vocabulary":
                ContentFrame.Navigate(typeof(VocabularySettingsPage));
                break;
            case "about":
                ContentFrame.Navigate(typeof(AboutPage));
                break;
        }
    }

    /// <summary>Wymuś okno na wierzch (z tray).</summary>
    public void BringToFront() => Activate();
}
