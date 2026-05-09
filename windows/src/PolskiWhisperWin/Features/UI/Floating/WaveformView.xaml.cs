// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using Microsoft.UI;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.UI;

namespace PolskiWhisperWin.Features.UI.Floating;

/// <summary>
/// Wizualizacja waveform - 80 słupków odzwierciedlających poziom RMS w czasie.
/// Mapping z macOS <c>WaveformView</c>.
/// </summary>
public sealed partial class WaveformView : UserControl
{
    private const int BarCount = 60;
    private const double BarWidth = 3.0;
    private const double BarSpacing = 1.0;
    private const double MinBarHeight = 3.0;
    private const double MaxBarHeight = 36.0;

    /// <summary>Bufor RMS samples - rolling window. Oldest sample = idx 0.</summary>
    private readonly double[] _rmsHistory = new double[BarCount];
    private readonly Rectangle[] _bars = new Rectangle[BarCount];

    private static readonly SolidColorBrush ActiveBrush = new(Color.FromArgb(255, 0xFF, 0x6B, 0x4A)); // Brand
    private static readonly SolidColorBrush IdleBrush = new(Color.FromArgb(80, 0xFF, 0x6B, 0x4A));

    public WaveformView()
    {
        InitializeComponent();
        BuildBars();
    }

    /// <summary>Domyślnie: brak intensity. Active gdy nagrywamy.</summary>
    public bool IsActive { get; set; } = false;

    /// <summary>Push nowy RMS sample - aktualizuje rolling window i przerysowuje słupki.</summary>
    public void PushSample(double rms)
    {
        // Shift history o 1 w lewo, append rms na końcu.
        Array.Copy(_rmsHistory, 1, _rmsHistory, 0, BarCount - 1);
        _rmsHistory[BarCount - 1] = rms;

        UpdateBars();
    }

    /// <summary>Reset waveform do zera.</summary>
    public void Reset()
    {
        for (int i = 0; i < BarCount; i++) _rmsHistory[i] = 0;
        UpdateBars();
    }

    private void BuildBars()
    {
        WaveformCanvas.Children.Clear();
        var totalWidth = BarCount * (BarWidth + BarSpacing);
        WaveformCanvas.Width = totalWidth;

        for (int i = 0; i < BarCount; i++)
        {
            var bar = new Rectangle
            {
                Width = BarWidth,
                Height = MinBarHeight,
                RadiusX = BarWidth / 2,
                RadiusY = BarWidth / 2,
                Fill = IdleBrush
            };

            var x = i * (BarWidth + BarSpacing);
            Canvas.SetLeft(bar, x);
            Canvas.SetTop(bar, (MaxBarHeight - MinBarHeight) / 2);

            _bars[i] = bar;
            WaveformCanvas.Children.Add(bar);
        }
    }

    private void UpdateBars()
    {
        for (int i = 0; i < BarCount; i++)
        {
            var rms = _rmsHistory[i];
            // Skala: rms 0..1 → height MinBarHeight..MaxBarHeight z eksponencjalną krzywą.
            var normalized = Math.Min(1.0, Math.Sqrt(Math.Max(0, rms) * 5));
            var h = MinBarHeight + (MaxBarHeight - MinBarHeight) * normalized;
            _bars[i].Height = h;
            Canvas.SetTop(_bars[i], (MaxBarHeight - h) / 2);
            _bars[i].Fill = IsActive ? ActiveBrush : IdleBrush;
        }
    }
}
