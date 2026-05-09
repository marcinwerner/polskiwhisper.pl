// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Reflection;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Features.Updates;

namespace PolskiWhisperWin.Features.UI.Pages;

/// <summary>
/// Zakładka O programie - informacje o aplikacji + DuplicateAppFinder.
/// </summary>
public sealed partial class AboutPage : Page
{
    public ObservableCollection<DuplicateApp> Duplicates { get; } = new();

    public AboutPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        DuplicatesListView.ItemsSource = Duplicates;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        if (version is not null)
        {
            VersionTextBlock.Text = $"Wersja {version.Major}.{version.Minor}.{version.Build}";
        }
    }

    private async void ScanDuplicatesButton_Click(object sender, RoutedEventArgs e)
    {
        ScanDuplicatesButton.IsEnabled = false;
        ScanDuplicatesButton.Content = "Skanuję...";
        Duplicates.Clear();

        try
        {
            var finder = App.Coordinator.Services.GetRequiredService<DuplicateAppFinder>();
            var found = await finder.FindDuplicatesAsync();

            foreach (var dup in found) Duplicates.Add(dup);

            if (found.Count == 0)
            {
                ScanDuplicatesButton.Content = "Brak kopii ✓";
                DuplicatesListView.Visibility = Visibility.Collapsed;
                CleanDuplicatesButton.Visibility = Visibility.Collapsed;
            }
            else
            {
                ScanDuplicatesButton.Content = $"Znaleziono {found.Count} kopii";
                DuplicatesListView.Visibility = Visibility.Visible;
                CleanDuplicatesButton.Visibility = Visibility.Visible;
            }
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogError(ex, "Scan duplicates nieudane.");
            ScanDuplicatesButton.Content = "Błąd skanowania";
        }
        finally
        {
            ScanDuplicatesButton.IsEnabled = true;
        }
    }

    private async void CleanDuplicatesButton_Click(object sender, RoutedEventArgs e)
    {
        if (Duplicates.Count == 0) return;

        var dialog = new ContentDialog
        {
            Title = "Wyrzucić do kosza?",
            Content = $"Znalezione kopie ({Duplicates.Count}) zostaną przeniesione do Kosza. Możesz je przywrócić w razie potrzeby.",
            PrimaryButtonText = "Wyrzuć",
            CloseButtonText = "Anuluj",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot
        };

        var result = await dialog.ShowAsync();
        if (result != ContentDialogResult.Primary) return;

        var finder = App.Coordinator.Services.GetRequiredService<DuplicateAppFinder>();
        foreach (var dup in Duplicates.ToArray())
        {
            if (finder.MoveToTrash(dup))
            {
                Duplicates.Remove(dup);
            }
        }

        if (Duplicates.Count == 0)
        {
            DuplicatesListView.Visibility = Visibility.Collapsed;
            CleanDuplicatesButton.Visibility = Visibility.Collapsed;
            ScanDuplicatesButton.Content = "Wszystkie kopie usunięte ✓";
        }
    }
}
