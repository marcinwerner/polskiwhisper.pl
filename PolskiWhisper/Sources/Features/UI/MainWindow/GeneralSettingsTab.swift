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

    @AppStorage(AppCoordinator.Keys.playSounds) private var playSounds: Bool = true
    @AppStorage(AppCoordinator.Keys.maxRecordingDuration) private var maxDuration: Double = 300
    @AppStorage(AppCoordinator.Keys.selectedStartSound) private var selectedStartSoundRaw: String = SoundService.SoundChoice.pop.rawValue
    @AppStorage(AppCoordinator.Keys.selectedFinishSound) private var selectedFinishSoundRaw: String = SoundService.SoundChoice.tink.rawValue

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

    @State private var updateChecker = UpdateChecker.shared

    var body: some View {
        Form {
            // Sekcja aktualizacji - banner + force check button
            Section("Aktualizacje") {
                if let update = updateChecker.availableUpdate {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dostępna nowa wersja: PolskiWhisper v\(update.version)")
                                .font(.headline)
                            Text("Aktualnie używasz v\(Bundle.main.appVersion). Pobierz nowy DMG z GitHub.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Otwórz GitHub") {
                            NSWorkspace.shared.open(update.releaseNotesURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Aplikacja jest aktualna (v\(Bundle.main.appVersion))")
                            .font(.body)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await UpdateChecker.shared.forceCheck() }
                    } label: {
                        if updateChecker.isChecking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Sprawdzam...")
                            }
                        } else {
                            Label("Sprawdź teraz", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(updateChecker.isChecking)
                    .controlSize(.small)

                    Spacer()

                    if let last = updateChecker.lastCheckedAt {
                        Text("Ostatnio sprawdzono: \(Self.formatRelative(last))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Jeszcze nie sprawdzano")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Uruchamianie") {
                LaunchAtLogin.Toggle("Uruchamiaj przy logowaniu")

                Toggle("Pokaż ikonę w Docku", isOn: dockBinding)
                Text("Włączone: ikona w Docku jak każda inna aplikacja (klik aktywuje, Cmd+Tab znajduje). Wyłączone: tylko ikona w pasku menu (jak Spotlight, Bartender) - mniej miejsca w Docku.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dyktowanie") {
                Picker("Maksymalny czas nagrywania:", selection: $maxDuration) {
                    ForEach(Self.durationOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)

                Text("Po przekroczeniu limitu nagrywanie zatrzyma się automatycznie. \"Bez limitu\" = nagrywaj do tap stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dźwięki") {
                Toggle("Odtwarzaj dźwięki przy nagrywaniu", isOn: $playSounds)
                Text("Subtelny sygnał gdy zaczynasz i kończysz nagrywanie. Używa systemowych dźwięków macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Posłuchaj dostępnych dźwięków:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                soundTestGrid

                Picker("Dźwięk rozpoczęcia:", selection: $selectedStartSoundRaw) {
                    ForEach(SoundService.SoundChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!playSounds)

                Picker("Dźwięk zakończenia:", selection: $selectedFinishSoundRaw) {
                    ForEach(SoundService.SoundChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!playSounds)
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

    /// Formatowanie czasu względnego - "5 min temu", "2 godz. temu", "wczoraj".
    /// Używane dla "Ostatnio sprawdzono..." pod buttonem aktualizacji.
    private static func formatRelative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Grid 3x3 z 9 buttonami - klik = play danego dźwięku.
    /// Pomaga user'owi wybrać który dźwięk preferuje przed ustawieniem w Picker.
    private var soundTestGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SoundService.SoundChoice.allCases) { choice in
                Button {
                    SoundService.playTest(choice)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(choice.rawValue)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .controlSize(.small)
            }
        }
    }
}
