//
//  AboutTab.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import SwiftUI

struct AboutTab: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text("PolskiWhisper")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Wersja \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider().padding(.horizontal, 60)

                VStack(spacing: 8) {
                    Text("Natywna macOS aplikacja do promptowania głosowego po polsku.")
                        .multilineTextAlignment(.center)
                    Text("W pełni offline, otwarte źródło, MIT.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider().padding(.horizontal, 60)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Komponenty open source:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        ackLink("WhisperKit (Apache 2.0)", url: "https://github.com/argmaxinc/WhisperKit")
                        ackLink("OpenAI Whisper (MIT)", url: "https://github.com/openai/whisper")
                        ackLink("LaunchAtLogin-Modern (MIT)", url: "https://github.com/sindresorhus/LaunchAtLogin-Modern")
                        ackLink("GRDB.swift (MIT)", url: "https://github.com/groue/GRDB.swift")
                    }
                    .font(.callout)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().padding(.horizontal, 60)

                HStack(spacing: 16) {
                    Button("Repo na GitHub") {
                        open("https://github.com/marcinwerner/polskiwhisper.pl")
                    }
                    Button("Polityka prywatności") {
                        open("https://github.com/marcinwerner/polskiwhisper.pl/blob/main/docs/PRIVACY.md")
                    }
                }

                Divider().padding(.horizontal, 60)

                VStack(spacing: 8) {
                    Text("Konfiguracja")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button("Pokaż onboarding ponownie") {
                            AppCoordinator.shared.onboardingCompleted = false
                            OnboardingFlow.shared.show()
                        }
                        Button("Resetuj wszystkie ustawienia...") {
                            confirmAndResetSettings()
                        }
                        .foregroundStyle(.red)
                    }
                    Text("Reset usuwa wszystkie ustawienia (NIE usuwa słownika ani modeli Whisper).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("© 2026 Marcin Werner")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }
    }

    @ViewBuilder
    private func ackLink(_ label: String, url: String) -> some View {
        HStack {
            Text("•")
            Button(label) { open(url) }
                .buttonStyle(.link)
        }
    }

    private func open(_ url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }

    private func confirmAndResetSettings() {
        let alert = NSAlert()
        alert.messageText = "Resetować wszystkie ustawienia?"
        alert.informativeText = "Wszystkie preferencje (skróty, modele, dźwięki, motyw) zostaną przywrócone do wartości domyślnych. Słownik i pobrane modele Whisper NIE zostaną usunięte."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Resetuj")
        alert.addButton(withTitle: "Anuluj")

        if alert.runModal() == .alertFirstButtonReturn {
            // Usuń wszystkie klucze z UserDefaults dla naszego bundle
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
            }
            // Re-register defaults
            SoundService.registerDefaults()
            // Pokaż confirmation
            let done = NSAlert()
            done.messageText = "Ustawienia zresetowane"
            done.informativeText = "Aby zmiany weszły w życie, zrestartuj aplikację."
            done.runModal()
            Log.app.info("All settings reset to defaults")
        }
    }
}
