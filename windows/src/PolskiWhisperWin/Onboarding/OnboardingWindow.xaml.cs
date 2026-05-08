// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using PolskiWhisperWin.Onboarding.Steps;

namespace PolskiWhisperWin.Onboarding;

/// <summary>
/// Onboarding wizard - 5 kroków first-run experience.
/// Mapping z macOS <c>OnboardingFlow</c>.
/// </summary>
public sealed partial class OnboardingWindow : Window
{
    private readonly Type[] _steps =
    {
        typeof(WelcomeStep),
        typeof(MicrophoneStep),
        typeof(ModelStep),
        typeof(HotkeyStep),
        typeof(FinishStep),
    };

    private int _currentStepIndex;

    public OnboardingWindow()
    {
        InitializeComponent();
        Title = "PolskiWhisper - Konfiguracja";

        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.IsResizable = false;
            presenter.IsMaximizable = false;
        }

        ShowStep(0);
    }

    private void ShowStep(int index)
    {
        if (index < 0 || index >= _steps.Length) return;

        _currentStepIndex = index;
        ContentFrame.Navigate(_steps[index]);

        StepLabel.Text = $"Krok {index + 1} z {_steps.Length}";
        TitleLabel.Text = GetStepTitle(index);

        BackButton.IsEnabled = index > 0;
        NextButton.Content = index == _steps.Length - 1 ? "Zakończ" : "Dalej";
    }

    private static string GetStepTitle(int index) => index switch
    {
        0 => "Witaj w PolskiWhisper!",
        1 => "Konfiguracja mikrofonu",
        2 => "Pobranie modelu Whisper",
        3 => "Wybór skrótu klawiszowego",
        4 => "Wszystko gotowe!",
        _ => ""
    };

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (_currentStepIndex > 0) ShowStep(_currentStepIndex - 1);
    }

    private async void NextButton_Click(object sender, RoutedEventArgs e)
    {
        if (_currentStepIndex < _steps.Length - 1)
        {
            ShowStep(_currentStepIndex + 1);
        }
        else
        {
            await CompleteOnboardingAsync();
        }
    }

    private async void SkipButton_Click(object sender, RoutedEventArgs e)
    {
        await CompleteOnboardingAsync();
    }

    private async System.Threading.Tasks.Task CompleteOnboardingAsync()
    {
        var updated = App.Coordinator.Settings.Clone();
        updated.OnboardingCompleted = true;
        await App.Coordinator.UpdateSettingsAsync(updated);

        Close();
    }
}
