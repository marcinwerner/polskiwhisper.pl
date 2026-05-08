// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;

namespace PolskiWhisperWin.Onboarding.Steps;

public sealed partial class ModelStep : Page
{
    private DispatcherQueue _dispatcherQueue;

    public ModelStep()
    {
        InitializeComponent();
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
    }

    private async void DownloadButton_Click(object sender, RoutedEventArgs e)
    {
        DownloadButton.IsEnabled = false;
        DownloadProgress.Visibility = Visibility.Visible;
        StatusText.Visibility = Visibility.Visible;
        StatusText.Text = "Przygotowuję pobieranie...";

        try
        {
            var whisper = App.Coordinator.Services.GetRequiredService<IWhisperService>();
            var progress = new Progress<WhisperLoadProgress>(p =>
            {
                _dispatcherQueue.TryEnqueue(() =>
                {
                    DownloadProgress.Value = p.Progress * 100;
                    StatusText.Text = p.StatusMessage;
                });
            });

            await whisper.LoadModelAsync(WhisperModelInfo.Default.Identifier, progress);

            DownloadButton.Content = "Model pobrany ✓";
            StatusText.Text = "Gotowy do dyktowania!";
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Błąd: {ex.Message}";
            DownloadButton.IsEnabled = true;
        }
    }
}
