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
        VStack(spacing: 14) {
            // Hero - icon + name + version w jednej kolumnie, mniejszy footprint
            HStack(spacing: 16) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PolskiWhisper")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Wersja \(appVersion) · © 2026 Marcin Werner · MIT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Natywna macOS aplikacja do promptowania głosowego po polsku. W pełni offline, otwarte źródło.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Divider().padding(.horizontal, 40)

            // OSS - inline jako klikalne linki w jednym tekście
            VStack(spacing: 4) {
                Text("Zbudowane na:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ossLink("WhisperKit", url: "https://github.com/argmaxinc/WhisperKit")
                    Text("·").foregroundStyle(.secondary)
                    ossLink("OpenAI Whisper", url: "https://github.com/openai/whisper")
                    Text("·").foregroundStyle(.secondary)
                    ossLink("LaunchAtLogin", url: "https://github.com/sindresorhus/LaunchAtLogin-Modern")
                    Text("·").foregroundStyle(.secondary)
                    ossLink("GRDB.swift", url: "https://github.com/groue/GRDB.swift")
                }
                .font(.caption)
            }

            Divider().padding(.horizontal, 40)

            // Akcje - linki + buttons w jednej linii
            HStack(spacing: 8) {
                Button("Repo na GitHub") {
                    open("https://github.com/marcinwerner/polskiwhisper.pl")
                }
                Button("Polityka prywatności") {
                    open("https://github.com/marcinwerner/polskiwhisper.pl/blob/main/docs/PRIVACY.md")
                }
                Button("Pokaż onboarding") {
                    AppCoordinator.shared.onboardingCompleted = false
                    OnboardingFlow.shared.show()
                }
            }
            .controlSize(.small)

            Divider().padding(.horizontal, 40)

            // Reset - na dole, mniej eksponowane (ostrożność)
            VStack(spacing: 4) {
                Button("Resetuj wszystkie ustawienia...") {
                    confirmAndResetSettings()
                }
                .controlSize(.small)
                .foregroundStyle(.red)
                Text("Reset NIE usuwa słownika ani modeli Whisper")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func ossLink(_ label: String, url: String) -> some View {
        Button(label) { open(url) }
            .buttonStyle(.link)
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
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
            }
            SoundService.registerDefaults()
            let done = NSAlert()
            done.messageText = "Ustawienia zresetowane"
            done.informativeText = "Aby zmiany weszły w życie, zrestartuj aplikację."
            done.runModal()
            Log.app.info("All settings reset to defaults")
        }
    }
}
