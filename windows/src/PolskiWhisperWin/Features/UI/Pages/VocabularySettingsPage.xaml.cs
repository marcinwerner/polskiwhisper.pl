// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Collections.ObjectModel;
using System.Linq;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using Windows.System;

namespace PolskiWhisperWin.Features.UI.Pages;

/// <summary>
/// Zakładka Słownik - lista reguł Find &amp; Replace z drag-and-drop reorder.
/// Mapping z macOS <c>VocabularySettingsTab</c> (v0.1.4 UX).
/// </summary>
public sealed partial class VocabularySettingsPage : Page
{
    public ObservableCollection<FindReplaceRule> Rules { get; } = new();

    public VocabularySettingsPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        RulesListView.ItemsSource = Rules;
        Rules.CollectionChanged += async (_, _) =>
        {
            // Każda zmiana kolejności (drag-drop) → zapisuj.
            // CanReorderItems uruchamia CollectionChanged 2x (Remove + Insert) per drag.
            await SaveCurrentOrderAsync();
        };
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var store = App.Coordinator.Services.GetRequiredService<IVocabularyStore>();
            var rules = await store.GetAllRulesAsync();

            Rules.Clear();
            foreach (var r in rules) Rules.Add(r);
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogError(ex, "Wczytanie reguł nieudane.");
        }
    }

    private async void AddRuleButton_Click(object sender, RoutedEventArgs e)
    {
        await AddRuleAsync();
    }

    private async void OnNewRuleKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter)
        {
            e.Handled = true;
            await AddRuleAsync();
        }
    }

    private async System.Threading.Tasks.Task AddRuleAsync()
    {
        var find = FindTextBox.Text?.Trim() ?? "";
        var replace = ReplaceTextBox.Text ?? "";

        if (string.IsNullOrWhiteSpace(find)) return;

        try
        {
            var store = App.Coordinator.Services.GetRequiredService<IVocabularyStore>();
            var newRule = await store.AddRuleAsync(new FindReplaceRule(
                Id: 0,
                FindText: find,
                ReplaceWith: replace,
                IsRegex: false,
                CaseSensitive: false,
                OrderIndex: Rules.Count,
                CreatedAt: DateTime.UtcNow));

            Rules.Add(newRule);
            FindTextBox.Text = "";
            ReplaceTextBox.Text = "";
            FindTextBox.Focus(FocusState.Programmatic);
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogError(ex, "Add rule nieudane.");
        }
    }

    private async void DeleteRuleButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button btn) return;
        if (btn.Tag is not long ruleId) return;

        try
        {
            var store = App.Coordinator.Services.GetRequiredService<IVocabularyStore>();
            await store.DeleteRuleAsync(ruleId);

            var existing = Rules.FirstOrDefault(r => r.Id == ruleId);
            if (existing is not null) Rules.Remove(existing);
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogError(ex, "Delete rule nieudane.");
        }
    }

    private async System.Threading.Tasks.Task SaveCurrentOrderAsync()
    {
        try
        {
            var store = App.Coordinator.Services.GetRequiredService<IVocabularyStore>();
            var orderedIds = Rules.Select(r => r.Id).ToArray();
            await store.ReorderRulesAsync(orderedIds);
        }
        catch (Exception ex)
        {
            App.Coordinator.Logger.LogError(ex, "Reorder nieudane.");
        }
    }
}
