// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.IO;
using System.Linq;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Core.Utilities;

namespace PolskiWhisperWin.Features.UI.Pages;

/// <summary>
/// Zakładka Whisper - wybór modelu z auto-load po zmianie.
/// Mapping z macOS <c>WhisperSettingsTab</c> (Wave 2 picker UX).
/// </summary>
public sealed partial class WhisperSettingsPage : Page
{
    private bool _isLoading = true;
    private DispatcherQueue _dispatcherQueue;

    public WhisperSettingsPage()
    {
        InitializeComponent();
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            _isLoading = true;
            ModelsListView.ItemsSource = WhisperModelInfo.All;

            var current = WhisperModelInfo.FindOrDefault(App.Coordinator.Settings.SelectedWhisperModelId);
            ModelsListView.SelectedItem = current;
        }
        finally
        {
            _isLoading = false;
        }
    }

    private async void ModelsListView_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (ModelsListView.SelectedItem is not WhisperModelInfo selected) return;
        if (selected.Identifier == App.Coordinator.Settings.SelectedWhisperModelId) return;

        // Sprawdź czy model jest pobrany.
        var paths = App.Coordinator.Services.GetRequiredService<IAppPaths>();
        var modelPath = Path.Combine(paths.ModelsDirectory, $"{selected.Identifier}.bin");
        var alreadyDownloaded = File.Exists(modelPath);

        if (!alreadyDownloaded)
        {
            var dialog = new ContentDialog
            {
                Title = "Pobrać model?",
                Content = $"Model '{selected.DisplayName}' nie jest jeszcze pobrany. Pobranie zajmie chwilę (~{FormatBytes(selected.ApproximateSizeBytes)}).\n\nKontynuować?",
                PrimaryButtonText = "Pobierz",
                CloseButtonText = "Anuluj",
                DefaultButton = ContentDialogButton.Primary,
                XamlRoot = this.XamlRoot
            };

            var result = await dialog.ShowAsync();
            if (result != ContentDialogResult.Primary)
            {
                // Revert UI selection.
                _isLoading = true;
                var current = WhisperModelInfo.FindOrDefault(App.Coordinator.Settings.SelectedWhisperModelId);
                ModelsListView.SelectedItem = current;
                _isLoading = false;
                return;
            }
        }

        // Update settings.
        var updated = App.Coordinator.Settings.Clone();
        updated.SelectedWhisperModelId = selected.Identifier;
        await App.Coordinator.UpdateSettingsAsync(updated);

        // Load model in tle - pokazuj progress.
        LoadProgressBar.Visibility = Visibility.Visible;
        LoadStatusText.Visibility = Visibility.Visible;
        LoadStatusText.Text = "Przygotowuję...";

        try
        {
            var whisper = App.Coordinator.Services.GetRequiredService<IWhisperService>();
            var progress = new Progress<WhisperLoadProgress>(p =>
            {
                _dispatcherQueue.TryEnqueue(() =>
                {
                    LoadProgressBar.Value = p.Progress * 100;
                    LoadStatusText.Text = p.StatusMessage;
                });
            });

            await whisper.LoadModelAsync(selected.Identifier, progress);

            LoadProgressBar.Value = 100;
            LoadStatusText.Text = "Model gotowy.";
            await System.Threading.Tasks.Task.Delay(1500);
            LoadProgressBar.Visibility = Visibility.Collapsed;
            LoadStatusText.Visibility = Visibility.Collapsed;
        }
        catch (Exception ex)
        {
            LoadStatusText.Text = $"Błąd: {ex.Message}";
        }
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F0} KB";
        if (bytes < 1024L * 1024 * 1024) return $"{bytes / (1024.0 * 1024):F0} MB";
        return $"{bytes / (1024.0 * 1024 * 1024):F1} GB";
    }
}
