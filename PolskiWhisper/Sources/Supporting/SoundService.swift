//
//  SoundService.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Foundation

/// Odtwarzanie dźwięków UI feedback - subtelne, jak Superwhisper.
///
/// Używa systemowych dźwięków macOS (NSSound z `/System/Library/Sounds/`).
/// User wybiera dźwięk osobno dla:
/// - **Start nagrywania** (default: "Pop")
/// - **Zakończenie / wklejenie** (default: "Tink")
/// - **Błąd** (zawsze "Basso", nie wybierane)
///
/// Domyślnie WŁĄCZONE - user oczekuje audio feedback przy dyktowaniu.
/// Toggleable przez `AppCoordinator.Keys.playSounds` (Settings → Ogólne).
@MainActor
enum SoundService {

    /// Dostępne dźwięki systemowe macOS które user może wybrać dla start/finish.
    /// 9 starannie dobranych - krótkie, przyjazne, nie nachalne.
    enum SoundChoice: String, CaseIterable, Identifiable {
        case pop = "Pop"
        case tink = "Tink"
        case glass = "Glass"
        case ping = "Ping"
        case bottle = "Bottle"
        case purr = "Purr"
        case hero = "Hero"
        case submarine = "Submarine"
        case blow = "Blow"

        var id: String { rawValue }

        /// Krótka, przyjazna nazwa po polsku.
        var displayName: String {
            switch self {
            case .pop: return "Pop (krótki tap)"
            case .tink: return "Tink (delikatne pip)"
            case .glass: return "Glass (szklany dzwonek)"
            case .ping: return "Ping (krótki ping)"
            case .bottle: return "Bottle (clink)"
            case .purr: return "Purr (ciche burczenie)"
            case .hero: return "Hero (triumfalny)"
            case .submarine: return "Submarine (sonar)"
            case .blow: return "Blow (delikatny puff)"
            }
        }
    }

    /// Dźwięk błędu - hardcoded, nie konfigurowalny przez user.
    private static let errorSoundName = "Basso"

    /// Wywołać raz przy starcie aplikacji - ustawia defaults dla UserDefaults.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            AppCoordinator.Keys.playSounds: true,
            AppCoordinator.Keys.selectedStartSound: SoundChoice.pop.rawValue,
            AppCoordinator.Keys.selectedFinishSound: SoundChoice.tink.rawValue,
        ])
    }

    /// Odtwarza dźwięk startu nagrywania (jeśli włączony w Settings).
    /// Używa wybór z UserDefaults (default: Pop).
    static func playStart() {
        guard UserDefaults.standard.bool(forKey: AppCoordinator.Keys.playSounds) else {
            return
        }
        let raw = UserDefaults.standard.string(forKey: AppCoordinator.Keys.selectedStartSound)
            ?? SoundChoice.pop.rawValue
        playByName(raw)
    }

    /// Odtwarza dźwięk zakończenia (success paste).
    /// Używa wybór z UserDefaults (default: Tink).
    static func playFinish() {
        guard UserDefaults.standard.bool(forKey: AppCoordinator.Keys.playSounds) else {
            return
        }
        let raw = UserDefaults.standard.string(forKey: AppCoordinator.Keys.selectedFinishSound)
            ?? SoundChoice.tink.rawValue
        playByName(raw)
    }

    /// Odtwarza dźwięk błędu (paste failed lub inny error). Hardcoded "Basso".
    static func playError() {
        guard UserDefaults.standard.bool(forKey: AppCoordinator.Keys.playSounds) else {
            return
        }
        playByName(errorSoundName)
    }

    /// Test - odtwarza wybrany dźwięk **niezależnie** od `playSounds` toggle.
    /// Używane w Settings UI gdy user klika przycisk "posłuchaj" obok danego dźwięku.
    static func playTest(_ sound: SoundChoice) {
        playByName(sound.rawValue)
    }

    // MARK: - Private

    private static func playByName(_ name: String) {
        guard let nsSound = NSSound(named: name) else {
            Log.app.warning("System sound '\(name, privacy: .public)' not available")
            return
        }
        // Stop poprzedni instance jeśli ten sam dźwięk już gra (overlapping przy szybkim taptowaniu).
        if nsSound.isPlaying {
            nsSound.stop()
        }
        nsSound.play()
        Log.app.debug("Played sound: \(name, privacy: .public)")
    }
}
