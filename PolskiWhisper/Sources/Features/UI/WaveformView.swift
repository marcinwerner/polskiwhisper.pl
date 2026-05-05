//
//  WaveformView.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import SwiftUI

/// Real-time scrolling waveform - 80 bars, każdy reprezentuje peak audio w time slice ~21ms.
///
/// Stare bary zwijają się w lewo, nowe pojawiają się po prawej w czasie rzeczywistym.
/// Update rate: ~48 razy/sek (zależy od audio buffer size, zwykle 1024 samples).
///
/// Visual:
/// ```
///                       ▆▇▃▂▁
///                  ▁▂▄▆▇▆▆▃▂▁
///        ▁▁▂▃▄▅▆▆▆▆▆▆▆▆▆▅▄▃▂▁
///   ▁▁▂▃▄▆▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▆▅▃▂
/// ```
struct WaveformView: View {

    /// Rolling window peak samples (najnowsze na końcu).
    let samples: [Float]

    /// Liczba bars do wyrenderowania.
    private let barCount: Int = 80

    /// Spacing między bars w px.
    private let spacing: CGFloat = 1

    var body: some View {
        // Bez GeometryReader - powodował recursive layout cycle.
        // Bary mają width 1pt + spacing, HStack rozciąga się naturalnie do max.
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(level: sampleAt(index))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Zwraca peak sample dla konkretnego bara.
    /// Bary 0...N-1 reprezentują samples od najstarszego do najnowszego.
    private func sampleAt(_ index: Int) -> Float {
        // Mapowanie: bar 0 = najstarszy, bar N-1 = najnowszy
        let realIndex = samples.count - barCount + index
        if realIndex < 0 || realIndex >= samples.count {
            return 0  // brak sampla = pusty bar
        }
        return samples[realIndex]
    }
}

// MARK: - Single bar

private struct WaveformBar: View {
    let level: Float

    /// Kolor: gradient od ciemnego niebieskiego (idle) do jasnego niebieskiego (peak).
    /// Powyżej 0.85 - czerwony (clipping warning).
    private var color: Color {
        if level > 0.85 {
            return Color(red: 1.0, green: 0.35, blue: 0.4)
        }
        let t = Double(level)
        return Color(
            red: 0.3 + t * 0.3,
            green: 0.5 + t * 0.3,
            blue: 0.95
        )
    }

    var body: some View {
        // Stała wysokość kontenera 32px (frame parent), bar rośnie z level.
        // Bez GeometryReader - powodował recursive layout w hostingu NSPanel.
        let containerHeight: CGFloat = 32
        let height = max(2, CGFloat(level) * containerHeight)
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(height: height)
            .frame(height: containerHeight, alignment: .center)
            .animation(.linear(duration: 0.05), value: height)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Empty (idle/processing)
        WaveformView(samples: [])
            .frame(width: 200, height: 32)
            .background(.background)

        // Partial (właśnie zaczął nagrywać)
        WaveformView(samples: (0..<20).map { _ in Float.random(in: 0...0.6) })
            .frame(width: 200, height: 32)
            .background(.background)

        // Full (długie nagrywanie)
        WaveformView(samples: (0..<80).map { _ in Float.random(in: 0...0.7) })
            .frame(width: 200, height: 32)
            .background(.background)

        // Loud
        WaveformView(samples: (0..<80).map { _ in Float.random(in: 0.5...0.95) })
            .frame(width: 200, height: 32)
            .background(.background)
    }
    .padding()
}
