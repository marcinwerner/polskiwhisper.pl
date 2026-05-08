// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Linq;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Features.UI;
using PolskiWhisperWin.Features.Updates;
using PolskiWhisperWin.Supporting;

namespace PolskiWhisperWin.Features.UI.Pages;

/// <summary>
/// Zakładka Ogólne - hotkey, mikrofon, dźwięki, autostart, aktualizacje.
/// </summary>
public sealed partial class GeneralSettingsPage : Page
{
    private bool _isLoading = true;
    private UpdateInfo? _pendingUpdate;

    public GeneralSettingsPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            _isLoading = true;
            var settings = App.Coordinator.Settings;

            // Hotkey ComboBox.
            HotkeyComboBox.Items.Clear();
            foreach (var (label, vk) in HotkeyOptions.All)
            {
                HotkeyComboBox.Items.Add(new ComboBoxItem { Content = label, Tag = vk });
            }
            var currentHotkey = HotkeyComboBox.Items.OfType<ComboBoxItem>()
                .FirstOrDefault(i => (int?)i.Tag == settings.HotkeyVirtualKeyCode);
            if (currentHotkey is not null) HotkeyComboBox.SelectedItem = currentHotkey;
            else HotkeyComboBox.SelectedIndex = 0;

            // Hotkey mode.
            foreach (var item in HotkeyModeComboBox.Items.OfType<ComboBoxItem>())
            {
                if (item.Tag?.ToString() == settings.HotkeyMode.ToString())
                {
                    HotkeyModeComboBox.SelectedItem = item;
                    break;
                }
            }

            // Mikrofon list.
            var audioRecorder = App.Coordinator.Services.GetRequiredService<IAudioRecorder>();
            var microphones = audioRecorder.GetAvailableMicrophones();
            MicrophoneComboBox.Items.Clear();
            MicrophoneComboBox.Items.Add(new ComboBoxItem { Content = "Domyślny mikrofon", Tag = (string?)null });
            foreach (var mic in microphones)
            {
                MicrophoneComboBox.Items.Add(new ComboBoxItem { Content = mic.DisplayName, Tag = mic.Id });
            }
            var currentMic = MicrophoneComboBox.Items.OfType<ComboBoxItem>()
                .FirstOrDefault(i => (i.Tag as string) == settings.SelectedMicrophoneId);
            MicrophoneComboBox.SelectedItem = currentMic ?? MicrophoneComboBox.Items[0];

            // Sounds.
            PopulateSoundCombobox(StartSoundComboBox, settings.StartSound);
            PopulateSoundCombobox(FinishSoundComboBox, settings.FinishSound);

            // Max duration.
            foreach (var item in MaxDurationComboBox.Items.OfType<ComboBoxItem>())
            {
                if (int.TryParse(item.Tag?.ToString(), out var sec) && sec == settings.MaxRecordingSeconds)
                {
                    MaxDurationComboBox.SelectedItem = item;
                    break;
                }
            }

            // Toggles.
            var launchAtLogin = App.Coordinator.Services.GetRequiredService<LaunchAtLoginManager>();
            LaunchAtLoginToggle.IsOn = launchAtLogin.IsEnabled;

            AutoUpdatesToggle.IsOn = settings.AutomaticUpdatesEnabled;
            GpuToggle.IsOn = settings.UseGpuAcceleration;
        }
        finally
        {
            _isLoading = false;
        }
    }

    private static void PopulateSoundCombobox(ComboBox combo, SoundChoice current)
    {
        combo.Items.Clear();
        foreach (var choice in Enum.GetValues<SoundChoice>())
        {
            combo.Items.Add(new ComboBoxItem { Content = choice.ToDisplayName(), Tag = choice });
        }
        var match = combo.Items.OfType<ComboBoxItem>()
            .FirstOrDefault(i => (SoundChoice?)i.Tag == current);
        combo.SelectedItem = match ?? combo.Items[0];
    }

    private async void HotkeyComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (HotkeyComboBox.SelectedItem is not ComboBoxItem item) return;
        if (item.Tag is not int vk) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.HotkeyVirtualKeyCode = vk;
        await App.Coordinator.UpdateSettingsAsync(updated);

        App.Coordinator.HotkeyMonitor.ChangeHotkey(vk);
    }

    private async void HotkeyModeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (HotkeyModeComboBox.SelectedItem is not ComboBoxItem item) return;
        if (!Enum.TryParse<HotkeyMode>(item.Tag?.ToString(), out var mode)) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.HotkeyMode = mode;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void MicrophoneComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (MicrophoneComboBox.SelectedItem is not ComboBoxItem item) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.SelectedMicrophoneId = item.Tag as string;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void StartSoundComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (StartSoundComboBox.SelectedItem is not ComboBoxItem item) return;
        if (item.Tag is not SoundChoice choice) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.StartSound = choice;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void FinishSoundComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (FinishSoundComboBox.SelectedItem is not ComboBoxItem item) return;
        if (item.Tag is not SoundChoice choice) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.FinishSound = choice;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private void StartSoundPlayButton_Click(object sender, RoutedEventArgs e)
    {
        var soundService = App.Coordinator.Services.GetRequiredService<SoundService>();
        soundService.Play(App.Coordinator.Settings.StartSound);
    }

    private void FinishSoundPlayButton_Click(object sender, RoutedEventArgs e)
    {
        var soundService = App.Coordinator.Services.GetRequiredService<SoundService>();
        soundService.Play(App.Coordinator.Settings.FinishSound);
    }

    private async void MaxDurationComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (MaxDurationComboBox.SelectedItem is not ComboBoxItem item) return;
        if (!int.TryParse(item.Tag?.ToString(), out var sec)) return;

        var updated = App.Coordinator.Settings.Clone();
        updated.MaxRecordingSeconds = sec;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void LaunchAtLoginToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        var manager = App.Coordinator.Services.GetRequiredService<LaunchAtLoginManager>();
        manager.SetEnabled(LaunchAtLoginToggle.IsOn);

        var updated = App.Coordinator.Settings.Clone();
        updated.LaunchAtLogin = LaunchAtLoginToggle.IsOn;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void AutoUpdatesToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        var updated = App.Coordinator.Settings.Clone();
        updated.AutomaticUpdatesEnabled = AutoUpdatesToggle.IsOn;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void GpuToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        var updated = App.Coordinator.Settings.Clone();
        updated.UseGpuAcceleration = GpuToggle.IsOn;
        await App.Coordinator.UpdateSettingsAsync(updated);
    }

    private async void CheckUpdatesButton_Click(object sender, RoutedEventArgs e)
    {
        UpdateInfoBar.IsOpen = false;
        CheckUpdatesButton.IsEnabled = false;
        CheckUpdatesButton.Content = "Sprawdzam...";

        try
        {
            var checker = App.Coordinator.Services.GetRequiredService<IUpdateChecker>();
            var version = System.Reflection.Assembly.GetExecutingAssembly()
                .GetName().Version?.ToString(3) ?? "0.0.0";

            var update = await checker.CheckForUpdateAsync(version);

            if (update is { IsNewer: true })
            {
                _pendingUpdate = update;
                UpdateInfoBar.Severity = InfoBarSeverity.Success;
                UpdateInfoBar.Title = $"Dostępna wersja {update.LatestVersion}";
                UpdateInfoBar.Message = $"Aktualnie używasz {update.CurrentVersion}. Kliknij aby pobrać i zainstalować.";
                InstallUpdateButton.Visibility = Visibility.Visible;
                UpdateInfoBar.IsOpen = true;
            }
            else
            {
                _pendingUpdate = null;
                UpdateInfoBar.Severity = InfoBarSeverity.Informational;
                UpdateInfoBar.Title = "Masz najnowszą wersję";
                UpdateInfoBar.Message = $"Wersja {version} jest aktualna.";
                InstallUpdateButton.Visibility = Visibility.Collapsed;
                UpdateInfoBar.IsOpen = true;
            }
        }
        catch (Exception ex)
        {
            UpdateInfoBar.Severity = InfoBarSeverity.Error;
            UpdateInfoBar.Title = "Sprawdzenie nieudane";
            UpdateInfoBar.Message = ex.Message;
            UpdateInfoBar.IsOpen = true;
        }
        finally
        {
            CheckUpdatesButton.IsEnabled = true;
            CheckUpdatesButton.Content = "Sprawdź teraz";
        }
    }

    private async void InstallUpdateButton_Click(object sender, RoutedEventArgs e)
    {
        if (_pendingUpdate is null) return;

        InstallUpdateButton.IsEnabled = false;
        InstallUpdateButton.Content = "Pobieram...";

        try
        {
            var checker = App.Coordinator.Services.GetRequiredService<IUpdateChecker>();
            var progress = new Progress<double>(p =>
            {
                InstallUpdateButton.Content = $"Pobieram... {p * 100:F0}%";
            });

            var msiPath = await checker.DownloadInstallerAsync(_pendingUpdate, progress);
            InstallUpdateButton.Content = "Instaluję...";

            var installer = App.Coordinator.Services.GetRequiredService<SelfUpdateInstaller>();
            installer.InstallAndRestart(msiPath);
        }
        catch (Exception ex)
        {
            UpdateInfoBar.Severity = InfoBarSeverity.Error;
            UpdateInfoBar.Title = "Instalacja nieudana";
            UpdateInfoBar.Message = ex.Message;
            InstallUpdateButton.IsEnabled = true;
            InstallUpdateButton.Content = "Pobierz i zainstaluj";
        }
    }
}

/// <summary>Predefiniowana lista popularnych hotkey opcji do wyboru w UI.</summary>
internal static class HotkeyOptions
{
    public static readonly (string Label, int VirtualKeyCode)[] All =
    [
        ("Prawy Ctrl", 0xA3),
        ("Lewy Ctrl", 0xA2),
        ("Prawy Alt", 0xA5),
        ("Lewy Alt", 0xA4),
        ("Prawy Shift", 0xA1),
        ("Lewy Shift", 0xA0),
        ("Caps Lock", 0x14),
        ("Scroll Lock", 0x91),
        ("F1", 0x70),
        ("F2", 0x71),
        ("F3", 0x72),
        ("F4", 0x73),
        ("F12", 0x7B),
    ];
}
