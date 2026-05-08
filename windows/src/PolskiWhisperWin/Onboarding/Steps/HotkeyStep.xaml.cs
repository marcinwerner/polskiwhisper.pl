// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Features.UI.Pages;

namespace PolskiWhisperWin.Onboarding.Steps;

public sealed partial class HotkeyStep : Page
{
    private bool _isLoading = true;

    public HotkeyStep()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            _isLoading = true;
            HotkeyComboBox.Items.Clear();
            foreach (var (label, vk) in HotkeyOptions.All)
            {
                HotkeyComboBox.Items.Add(new ComboBoxItem { Content = label, Tag = vk });
            }

            var current = App.Coordinator.Settings.HotkeyVirtualKeyCode;
            var match = HotkeyComboBox.Items.OfType<ComboBoxItem>()
                .FirstOrDefault(i => (int?)i.Tag == current);
            HotkeyComboBox.SelectedItem = match ?? HotkeyComboBox.Items[0];

            ToggleModeRadio.IsChecked = App.Coordinator.Settings.HotkeyMode == HotkeyMode.Toggle;
            HoldModeRadio.IsChecked = App.Coordinator.Settings.HotkeyMode == HotkeyMode.Hold;

            ToggleModeRadio.Checked += async (_, _) =>
            {
                if (_isLoading) return;
                var u = App.Coordinator.Settings.Clone();
                u.HotkeyMode = HotkeyMode.Toggle;
                await App.Coordinator.UpdateSettingsAsync(u);
            };
            HoldModeRadio.Checked += async (_, _) =>
            {
                if (_isLoading) return;
                var u = App.Coordinator.Settings.Clone();
                u.HotkeyMode = HotkeyMode.Hold;
                await App.Coordinator.UpdateSettingsAsync(u);
            };
        }
        finally
        {
            _isLoading = false;
        }
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
}
