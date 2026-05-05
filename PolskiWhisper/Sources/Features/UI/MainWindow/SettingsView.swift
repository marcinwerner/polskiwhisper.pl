//
//  SettingsView.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import SwiftUI

/// Główne okno ustawień (otwierane przez Cmd+, lub menu bar → "Otwórz Ustawienia").
///
/// Zakładki (TabView):
/// - **Ogólne** - autostart, motyw, dźwięki
/// - **Whisper** - wybór modelu, język
/// - **LLM** - włącz/wyłącz post-processing, wybór modelu Ollama, system prompt
/// - **Słownictwo** - Custom Words, Find & Replace, AI Vocabulary
/// - **O programie** - wersja, licencje
struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("Ogólne", systemImage: "gearshape")
                }

            WhisperSettingsTab()
                .tabItem {
                    Label("Whisper", systemImage: "waveform")
                }

            LLMSettingsTab()
                .tabItem {
                    Label("Model AI", systemImage: "sparkles")
                }

            VocabularySettingsTab()
                .tabItem {
                    Label("Słownictwo", systemImage: "text.book.closed")
                }

            AboutTab()
                .tabItem {
                    Label("O programie", systemImage: "info.circle")
                }
        }
        .frame(width: 720, height: 520)
    }
}
