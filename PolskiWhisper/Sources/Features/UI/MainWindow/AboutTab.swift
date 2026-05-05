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
            // Hero - logo + nazwa + wersja
            VStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .padding(.top, 12)

                Text("PolskiWhisper")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Wersja \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal, 80)

            // Krótki opis aplikacji
            VStack(spacing: 4) {
                Text("Natywna macOS aplikacja do promptowania głosowego po polsku.")
                    .multilineTextAlignment(.center)
                Text("W pełni offline, otwarte źródło, licencja MIT.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .font(.callout)
            .padding(.horizontal, 32)

            Divider().padding(.horizontal, 80)

            // Komponenty open source - lista z bullet points
            VStack(alignment: .leading, spacing: 6) {
                Text("Komponenty open source")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 2)

                ackLink("WhisperKit (Apache 2.0)", url: "https://github.com/argmaxinc/WhisperKit")
                ackLink("OpenAI Whisper (MIT)", url: "https://github.com/openai/whisper")
                ackLink("LaunchAtLogin-Modern (MIT)", url: "https://github.com/sindresorhus/LaunchAtLogin-Modern")
                ackLink("GRDB.swift (MIT)", url: "https://github.com/groue/GRDB.swift")
            }
            .font(.callout)
            .padding(.horizontal, 80)

            Divider().padding(.horizontal, 80)

            // Akcje - linki zewnętrzne + onboarding
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Zgłoś błąd") {
                        open("https://github.com/marcinwerner/polskiwhisper.pl/issues/new")
                    }
                    Button("Zadaj pytanie") {
                        open("https://github.com/marcinwerner/polskiwhisper.pl/discussions")
                    }
                    Button("Repo na GitHub") {
                        open("https://github.com/marcinwerner/polskiwhisper.pl")
                    }
                }
                HStack(spacing: 8) {
                    Button("Polityka prywatności") {
                        open("https://github.com/marcinwerner/polskiwhisper.pl/blob/main/docs/PRIVACY.md")
                    }
                    Button("Pokaż onboarding ponownie") {
                        AppCoordinator.shared.onboardingCompleted = false
                        OnboardingFlow.shared.show()
                    }
                }
            }

            Divider().padding(.horizontal, 80)

            // Reset ustawień - na dole, mniej eksponowane bo destructive
            VStack(spacing: 4) {
                Button("Resetuj wszystkie ustawienia...") {
                    confirmAndResetSettings()
                }
                .controlSize(.small)
                .foregroundStyle(.red)
                Text("Reset usuwa preferencje, NIE usuwa słownika ani modeli Whisper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Copyright stopka
            Text("© 2026 Marcin Werner · PolskiWhisper")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func ackLink(_ label: String, url: String) -> some View {
        HStack(spacing: 6) {
            Text("•")
                .foregroundStyle(.secondary)
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
