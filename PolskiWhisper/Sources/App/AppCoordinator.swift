//
//  AppCoordinator.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Foundation
import Observation

/// Singleton trzymający globalny stan aplikacji.
///
/// Marked `@Observable` (macOS 14+) - SwiftUI views obserwujące właściwości będą się odświeżać.
///
/// Jest to **single source of truth** dla:
/// - Status nagrywania (idle / recording / processing)
/// - Aktualne ustawienia (przekazane z UserDefaults)
/// - Referencje do serwisów (DictationEngine, MenuBarController, etc.)
@MainActor
@Observable
final class AppCoordinator {

    // MARK: - Singleton

    static let shared = AppCoordinator()

    // MARK: - State

    /// Aktualna faza dyktowania.
    enum Phase: Equatable {
        case idle
        case loadingModel
        case recording(startedAt: Date)
        case processingWhisper
        case pasting
        case completed(transcriptLength: Int)
        case error(message: String)
    }

    var phase: Phase = .idle

    /// j2: Flaga "Whisper transcribing trwa dłużej niż zwykle" (>5s).
    /// Ustawiana przez DictationEngine po 5s w fazie `.processingWhisper`.
    /// FloatingDictationWindow obserwuje to i zmienia komunikat (np. "Pracuje...")
    /// żeby user wiedział że to NIE freeze.
    /// Resetowana do false przy dismissFloatingWindow (powrót do idle).
    var processingTakingLong: Bool = false

    /// Czy aplikacja zakończyła pierwszy uruchomienie (onboarding).
    /// Persist w UserDefaults pod kluczem `onboardingCompleted`.
    var onboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.onboardingCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.onboardingCompleted) }
    }

    // MARK: - Services

    /// Główny orchestrator dyktowania. Inicjalizowany w `start()` po sprawdzeniu uprawnień.
    var dictationEngine: DictationEngine?

    /// Kontroler menu bar. Inicjalizowany w `start()`.
    var menuBarController: MenuBarController?

    /// Monitor klawisza Left Option dla toggle hotkey. Inicjalizowany gdy accessibility granted.
    var hotkeyMonitor: ModifierKeyMonitor?

    // MARK: - Initialization

    private init() {
        Log.coordinator.info("AppCoordinator initialized")
    }

    /// Wywoływane przez AppDelegate po launch. Inicjalizuje serwisy.
    func start() {
        Log.coordinator.info("AppCoordinator starting services")

        // Register UserDefaults defaults (np. playSounds=true)
        SoundService.registerDefaults()

        // Wymuszenie init VocabularyStore - triggeruje DB migration przy starcie
        // (zamiast lazy przy first use). Dzięki temu migracje są zsynchronizowane
        // z release aplikacji, plus pipeline transcribe nie ma cold-start DB.
        _ = VocabularyStore.shared

        // Apply Dock visibility z Settings (default false - menu bar only)
        applyDockVisibility(showInDock)

        // Menu bar - zawsze dostępny
        menuBarController = MenuBarController()

        // DictationEngine - core orchestrator
        let engine = DictationEngine()
        dictationEngine = engine

        // Hotkey monitor - tylko jeśli accessibility granted
        // (jeśli nie, użytkownik dostanie ostrzeżenie i może otworzyć Settings)
        if PermissionsHelper.isAccessibilityGranted {
            startHotkeyMonitor()
        } else {
            Log.coordinator.warning("""
                Accessibility not granted - hotkey monitor disabled. \
                Enable in System Settings → Privacy & Security → Accessibility, then restart app.
                """)
        }

        // Preload Whisper model w tle - dzięki temu pierwszy tap Left Option
        // będzie natychmiastowy (model gotowy do transcribe).
        // Pierwsze uruchomienie pobiera ~1.5GB (3-5 min), kolejne lazy load z cache (~5s).
        Task.detached(priority: .userInitiated) {
            await engine.preloadModel()
        }

        // Skanuje typowe lokalizacje pod kątem starych kopii PolskiWhisper.app.
        // User po pobraniu DMG często zostawia plik w Downloads / Desktop - aplikacja
        // pomaga sprzątnąć (banner w Settings). Zero koszt dla większości userów (brak duplikatów).
        Task { @MainActor in
            DuplicateAppFinder.shared.scan()
        }

        Log.coordinator.info("AppCoordinator services initialized")
    }

    /// Tryb hotkey - toggle (tap on/off) lub hold (push-to-talk).
    var hotkeyMode: ModifierKeyMonitor.Mode {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.hotkeyMode) ?? "toggle"
            return raw == "hold" ? .hold : .toggle
        }
        set {
            UserDefaults.standard.set(newValue == .hold ? "hold" : "toggle", forKey: Keys.hotkeyMode)
            // Re-init monitor z nowym trybem
            hotkeyMonitor?.stop()
            hotkeyMonitor = nil
            if PermissionsHelper.isAccessibilityGranted {
                startHotkeyMonitor()
            }
        }
    }

    /// Próbuje wystartować hotkey monitor (po grant accessibility).
    func startHotkeyMonitor() {
        guard hotkeyMonitor == nil else { return }

        let choice = selectedHotkey
        let mode = hotkeyMode

        let monitor: ModifierKeyMonitor
        switch mode {
        case .toggle:
            monitor = ModifierKeyMonitor(
                target: choice.monitorKey,
                mode: .toggle,
                onTap: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let engine = self?.dictationEngine else { return }
                        await engine.toggle()
                    }
                }
            )
        case .hold:
            monitor = ModifierKeyMonitor(
                target: choice.monitorKey,
                mode: .hold,
                onHoldStart: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let engine = self?.dictationEngine else { return }
                        await engine.startDictation()
                    }
                },
                onHoldEnd: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let engine = self?.dictationEngine else { return }
                        await engine.stopDictation()
                    }
                }
            )
        }

        if monitor.start() {
            hotkeyMonitor = monitor
            Log.coordinator.info("""
                Hotkey monitor started: \(choice.displayName, privacy: .public) \
                mode=\(String(describing: mode), privacy: .public)
                """)
        } else {
            Log.coordinator.error("Failed to start hotkey monitor")
        }
    }

    // MARK: - UserDefaults keys

    /// Klucze UserDefaults. Wszystkie klucze aplikacji powinny być tutaj zdefiniowane,
    /// aby uniknąć typo-based bugów i mieć single source of truth.
    enum Keys {
        static let onboardingCompleted = "onboardingCompleted"
        static let selectedWhisperModel = "selectedWhisperModel"
        static let hotkeyMode = "hotkeyMode" // "toggle" | "hold"
        static let selectedHotkey = "selectedHotkey"
        static let playSounds = "playSounds"
        static let selectedStartSound = "selectedStartSound"  // SoundService.SoundChoice rawValue
        static let selectedFinishSound = "selectedFinishSound"
        static let floatingWindowPosition = "floatingWindowPosition"
        static let launchAtLogin = "launchAtLogin"
        static let maxRecordingDuration = "maxRecordingDurationSeconds"
        static let showInDock = "showInDock"
        static let autoUpdateEnabled = "autoUpdateEnabled"  // opt-in auto-install nowych wersji
    }

    /// Czy aplikacja pokazuje ikonę w Docku.
    /// Default: false (menu bar app, jak iStat / Bartender / Spotlight).
    /// True: jak Superwhisper (Dock + menu bar).
    var showInDock: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showInDock) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showInDock)
            applyDockVisibility(newValue)
        }
    }

    /// Aplikuje activation policy zgodnie z wartością `showInDock`.
    /// Wywoływane przy starcie aplikacji oraz przy zmianie toggle.
    func applyDockVisibility(_ show: Bool) {
        NSApp.setActivationPolicy(show ? .regular : .accessory)
        Log.coordinator.info("Dock visibility: \(show ? "regular (with Dock)" : "accessory (menu bar only)", privacy: .public)")
    }

    // MARK: - Hotkey configuration

    /// Dostępne klawisze do ustawienia jako hotkey (single-modifier tap).
    enum HotkeyChoice: String, CaseIterable, Identifiable {
        case leftOption
        case rightOption
        case leftCommand
        case rightCommand
        case fn

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .leftOption: return "Lewy Option (⌥)"
            case .rightOption: return "Prawy Option (⌥)"
            case .leftCommand: return "Lewy Command (⌘)"
            case .rightCommand: return "Prawy Command (⌘)"
            case .fn: return "Fn (klawisz funkcyjny)"
            }
        }

        /// Czy ten klawisz koliduje z polskimi znakami diakrytycznymi (Polish keyboard layout).
        var conflictsWithPolishCharacters: Bool {
            switch self {
            case .leftOption, .rightOption: return true
            default: return false
            }
        }

        var monitorKey: ModifierKeyMonitor.Key {
            switch self {
            case .leftOption: return .leftOption
            case .rightOption: return .rightOption
            case .leftCommand: return .leftCommand
            case .rightCommand: return .rightCommand
            case .fn: return .fn
            }
        }
    }

    /// Wybrany hotkey - default Lewy Option.
    var selectedHotkey: HotkeyChoice {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.selectedHotkey)
                ?? HotkeyChoice.leftOption.rawValue
            return HotkeyChoice(rawValue: raw) ?? .leftOption
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.selectedHotkey)
            // Re-init hotkey monitor z nowym klawiszem
            hotkeyMonitor?.stop()
            hotkeyMonitor = nil
            if PermissionsHelper.isAccessibilityGranted {
                startHotkeyMonitor()
            }
            // Refresh menu bar (label "Gotowy do dyktowania (X)" pokazuje aktualny hotkey)
            menuBarController?.refresh()
            Log.coordinator.info("Hotkey changed to \(newValue.rawValue, privacy: .public)")
        }
    }

}
