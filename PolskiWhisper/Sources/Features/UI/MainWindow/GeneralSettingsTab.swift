//
//  GeneralSettingsTab.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsTab: View {

    @AppStorage(AppCoordinator.Keys.autoPaste) private var autoPaste: Bool = true
    @AppStorage(AppCoordinator.Keys.playSounds) private var playSounds: Bool = false
    @AppStorage(AppCoordinator.Keys.maxRecordingDuration) private var maxDuration: Double = 300

    // @AppStorage dla reactive UI - custom Binding z AppCoordinator getterem
    // NIE jest observable przez SwiftUI (UserDefaults read nie triggeruje view update).
    // @AppStorage rozwiązuje to - SwiftUI śledzi zmiany w UserDefaults.
    @AppStorage(AppCoordinator.Keys.selectedHotkey) private var selectedHotkeyRaw: String = AppCoordinator.HotkeyChoice.leftOption.rawValue
    @AppStorage(AppCoordinator.Keys.hotkeyMode) private var hotkeyModeRaw: String = "toggle"
    @AppStorage(AppCoordinator.Keys.showInDock) private var showInDockRaw: Bool = false

    /// Binding dla hotkey selection - get z @AppStorage (reactive),
    /// set przekierowuje przez AppCoordinator (re-init monitor + menu bar refresh).
    private var hotkeyBinding: Binding<AppCoordinator.HotkeyChoice> {
        Binding(
            get: { AppCoordinator.HotkeyChoice(rawValue: selectedHotkeyRaw) ?? .leftOption },
            set: { newValue in AppCoordinator.shared.selectedHotkey = newValue }
        )
    }

    /// Binding dla hotkey mode - true=hold, false=toggle.
    private var hotkeyModeBinding: Binding<Bool> {
        Binding(
            get: { hotkeyModeRaw == "hold" },
            set: { newValue in AppCoordinator.shared.hotkeyMode = newValue ? .hold : .toggle }
        )
    }

    /// Binding dla Dock visibility.
    private var dockBinding: Binding<Bool> {
        Binding(
            get: { showInDockRaw },
            set: { newValue in AppCoordinator.shared.showInDock = newValue }
        )
    }

    /// Opcje max duration w sekundach (0 = bez limitu).
    private static let durationOptions: [(seconds: Double, label: String)] = [
        (60, "1 minuta"),
        (180, "3 minuty"),
        (300, "5 minut (default)"),
        (600, "10 minut"),
        (1800, "30 minut"),
        (3600, "1 godzina"),
        (0, "Bez limitu")
    ]

    var body: some View {
        Form {
            Section("Uruchamianie") {
                LaunchAtLogin.Toggle("Uruchamiaj przy logowaniu")

                Toggle("Pokaż ikonę w Docku", isOn: dockBinding)
                Text("Włączone: ikona w Docku jak każda inna aplikacja (klik aktywuje, Cmd+Tab znajduje). Wyłączone: tylko ikona w pasku menu (jak Spotlight, Bartender) - mniej miejsca w Docku.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dyktowanie") {
                Toggle("Automatyczne wklejanie (Cmd+V)", isOn: $autoPaste)
                Text("Gdy wyłączone - tekst trafi do schowka, wklej ręcznie.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Maksymalny czas nagrywania:", selection: $maxDuration) {
                    ForEach(Self.durationOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)

                Text("Po przekroczeniu limitu nagrywanie zatrzyma się automatycznie. \"Bez limitu\" = nagrywaj do tap stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Dźwięki rozpoczęcia i zakończenia", isOn: $playSounds)
                Text("Subtelny \"Pop\" przy starcie nagrywania, \"Tink\" przy wklejeniu tekstu. Używa systemowych dźwięków macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Test start") {
                        SoundService.playStartTest()
                    }
                    .controlSize(.small)
                    Button("Test stop") {
                        SoundService.playFinishTest()
                    }
                    .controlSize(.small)
                }
            }

            Section("Skrót klawiszowy") {
                Picker("Klawisz:", selection: hotkeyBinding) {
                    ForEach(AppCoordinator.HotkeyChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .pickerStyle(.menu)

                Picker("Tryb:", selection: hotkeyModeBinding) {
                    Text("Przełącznik (kliknięcie start, kliknięcie stop)").tag(false)
                    Text("Przytrzymanie (trzymaj klawisz aby nagrywać)").tag(true)
                }
                .pickerStyle(.menu)

                if AppCoordinator.shared.selectedHotkey.conflictsWithPolishCharacters {
                    Text("⚠️ Ten klawisz może kolidować z wprowadzaniem polskich znaków (ą, ę, ś, ć, etc.). Jeśli używasz polskiego layoutu klawiatury, rozważ Fn lub Command.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("**Przełącznik**: kliknij raz aby rozpocząć, kliknij ponownie aby zakończyć. **Przytrzymanie**: naciśnij i trzymaj podczas mówienia, puść aby zakończyć.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
