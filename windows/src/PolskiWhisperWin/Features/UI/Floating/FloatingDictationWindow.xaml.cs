// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using Windows.Graphics;
using WinUIEx;

namespace PolskiWhisperWin.Features.UI.Floating;

/// <summary>
/// Pływające okienko podczas dyktowania - waveform + status.
/// Mapping z macOS <c>FloatingDictationWindow</c>.
/// </summary>
/// <remarks>
/// <para>Pozycja: górna-środkowa część ekranu, przesunięte 60px od góry.</para>
/// <para>Topmost = true (zawsze na wierzchu).</para>
/// <para>Click-through = NIE (user musi móc kliknąć Esc / poza nim aby przerwać).</para>
/// </remarks>
public sealed partial class FloatingDictationWindow : WindowEx
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly DictationEngine _dictationEngine;
    private readonly IAudioRecorder _audioRecorder;

    public FloatingDictationWindow(DictationEngine dictationEngine, IAudioRecorder audioRecorder)
    {
        InitializeComponent();
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        _dictationEngine = dictationEngine;
        _audioRecorder = audioRecorder;

        // Konfiguracja: borderless, no resize, topmost.
        IsAlwaysOnTop = true;
        IsMaximizable = false;
        IsMinimizable = false;
        IsResizable = false;
        IsTitleBarVisible = false;
        IsShownInSwitchers = false;

        PositionAtTopCenter();

        _dictationEngine.PhaseChanged += OnPhaseChanged;
        _audioRecorder.RmsLevelChanged += OnRmsChanged;

        Closed += (_, _) =>
        {
            _dictationEngine.PhaseChanged -= OnPhaseChanged;
            _audioRecorder.RmsLevelChanged -= OnRmsChanged;
        };
    }

    private void PositionAtTopCenter()
    {
        var monitor = DisplayArea.GetFromWindowId(this.AppWindow.Id, DisplayAreaFallback.Primary);
        if (monitor is null) return;

        var workArea = monitor.WorkArea;
        var x = workArea.X + (workArea.Width - 320) / 2;
        var y = workArea.Y + 60;

        AppWindow.Move(new PointInt32(x, y));
        AppWindow.Resize(new SizeInt32(320, 80));
    }

    private void OnPhaseChanged(object? sender, AppPhase phase)
    {
        _dispatcherQueue.TryEnqueue(() => UpdateUiForPhase(phase));
    }

    private void OnRmsChanged(object? sender, double rms)
    {
        _dispatcherQueue.TryEnqueue(() =>
        {
            if (_dictationEngine.Phase == AppPhase.Recording)
            {
                Waveform.PushSample(rms);
            }
        });
    }

    private void UpdateUiForPhase(AppPhase phase)
    {
        switch (phase)
        {
            case AppPhase.Recording:
                StatusIcon.Glyph = ""; // Mic
                Waveform.IsActive = true;
                Waveform.Visibility = Visibility.Visible;
                ProcessingRing.IsActive = false;
                ProcessingRing.Visibility = Visibility.Collapsed;
                StatusText.Visibility = Visibility.Collapsed;
                HintLabel.Visibility = Visibility.Visible;
                break;

            case AppPhase.Processing:
                StatusIcon.Glyph = ""; // Sound waves / processing
                Waveform.IsActive = false;
                Waveform.Visibility = Visibility.Collapsed;
                ProcessingRing.IsActive = true;
                ProcessingRing.Visibility = Visibility.Visible;
                StatusText.Text = "Przetwarzanie...";
                StatusText.Visibility = Visibility.Visible;
                HintLabel.Visibility = Visibility.Collapsed;
                break;

            case AppPhase.Pasting:
                StatusText.Text = "Wklejanie...";
                StatusText.Visibility = Visibility.Visible;
                ProcessingRing.IsActive = true;
                break;

            case AppPhase.Completed:
                StatusIcon.Glyph = ""; // Checkmark
                Waveform.IsActive = false;
                Waveform.Visibility = Visibility.Collapsed;
                ProcessingRing.IsActive = false;
                ProcessingRing.Visibility = Visibility.Collapsed;
                StatusText.Text = "Gotowe ✓";
                StatusText.Visibility = Visibility.Visible;
                HintLabel.Visibility = Visibility.Collapsed;
                break;

            case AppPhase.Error:
                StatusIcon.Glyph = ""; // Error
                StatusText.Text = "Błąd - spróbuj ponownie";
                StatusText.Visibility = Visibility.Visible;
                Waveform.Visibility = Visibility.Collapsed;
                ProcessingRing.Visibility = Visibility.Collapsed;
                break;

            case AppPhase.Idle:
            default:
                Hide();
                Waveform.Reset();
                break;
        }
    }
}
