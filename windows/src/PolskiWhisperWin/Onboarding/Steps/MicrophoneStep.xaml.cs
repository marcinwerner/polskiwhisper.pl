// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Linq;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Core.Services;

namespace PolskiWhisperWin.Onboarding.Steps;

public sealed partial class MicrophoneStep : Page
{
    private bool _isTesting;
    private DispatcherQueue _dispatcherQueue;

    public MicrophoneStep()
    {
        InitializeComponent();
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var recorder = App.Coordinator.Services.GetRequiredService<IAudioRecorder>();
            var mics = recorder.GetAvailableMicrophones();

            MicrophoneComboBox.Items.Clear();
            MicrophoneComboBox.Items.Add(new ComboBoxItem { Content = "Domyślny mikrofon", Tag = (string?)null });
            foreach (var m in mics)
            {
                MicrophoneComboBox.Items.Add(new ComboBoxItem { Content = m.DisplayName, Tag = m.Id });
            }
            MicrophoneComboBox.SelectedIndex = 0;
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogWarning(ex, "Listowanie mikrofonów nieudane.");
        }
    }

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        StopTest();
    }

    private async void MicrophoneComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (MicrophoneComboBox.SelectedItem is not ComboBoxItem item) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.SelectedMicrophoneId = item.Tag as string;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void TestButton_Click(object sender, RoutedEventArgs e)
    {
        if (_isTesting)
        {
            StopTest();
            return;
        }

        try
        {
            _isTesting = true;
            TestButton.Content = "Zatrzymaj test";

            var recorder = App.Coordinator.Services.GetRequiredService<IAudioRecorder>();
            recorder.RmsLevelChanged += OnRmsChanged;
            await recorder.StartRecordingAsync();
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogError(ex, "Test mikrofonu nieudany.");
            StopTest();
        }
    }

    private void OnRmsChanged(object? sender, double rms)
    {
        _dispatcherQueue.TryEnqueue(() =>
        {
            // Skala 0..1 → 0..100 z amplification dla user feedback.
            var pct = Math.Min(100, rms * 500);
            LevelBar.Value = pct;
        });
    }

    private async void StopTest()
    {
        if (!_isTesting) return;

        try
        {
            var recorder = App.Coordinator.Services.GetRequiredService<IAudioRecorder>();
            recorder.RmsLevelChanged -= OnRmsChanged;
            var result = await recorder.StopRecordingAsync();
            if (result is not null) recorder.CleanupRecording(result.WavFilePath);
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogWarning(ex, "Stop test nieudany.");
        }
        finally
        {
            _isTesting = false;
            TestButton.Content = "Rozpocznij test";
            LevelBar.Value = 0;
        }
    }
}
