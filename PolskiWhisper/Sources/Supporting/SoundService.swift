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
/// Używa systemowych dźwięków macOS (NSSound z `/System/Library/Sounds/`):
/// - **Start nagrywania**: "Pop" - subtelny pop (jak Superwhisper start)
/// - **Zakończenie + wklejenie**: "Tink" - delikatne pip
/// - **Błąd**: "Basso" - niski ton ostrzegawczy
///
/// Domyślnie WŁĄCZONE - user oczekuje audio feedback przy dyktowaniu.
/// Toggleable przez `AppCoordinator.Keys.playSounds` (Settings → Ogólne).
@MainActor
enum SoundService {

    private enum SystemSound: String {
        case start = "Pop"
        case finish = "Tink"
        case error = "Basso"
    }

    /// Wywołać raz przy starcie aplikacji - ustawia default true dla playSounds.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            AppCoordinator.Keys.playSounds: true,
        ])
    }

    /// Odtwarza dźwięk startu nagrywania (jeśli włączony w Settings).
    static func playStart() {
        play(.start)
    }

    /// Odtwarza dźwięk zakończenia (success paste).
    static func playFinish() {
        play(.finish)
    }

    /// Odtwarza dźwięk błędu (paste failed lub inny error).
    static func playError() {
        play(.error)
    }

    /// Test - odtwarza dźwięk start nawet jeśli sounds disabled. Używane w Settings UI.
    static func playStartTest() {
        if let nsSound = NSSound(named: SystemSound.start.rawValue) {
            nsSound.play()
        }
    }

    /// Test - odtwarza dźwięk finish nawet jeśli sounds disabled.
    static func playFinishTest() {
        if let nsSound = NSSound(named: SystemSound.finish.rawValue) {
            nsSound.play()
        }
    }

    // MARK: - Private

    private static func play(_ sound: SystemSound) {
        guard UserDefaults.standard.bool(forKey: AppCoordinator.Keys.playSounds) else {
            return  // sounds disabled
        }
        if let nsSound = NSSound(named: sound.rawValue) {
            // Stop poprzedni instance jeśli ten sam dźwięk już gra
            // (gdy user szybko taptuje, multiple "Tink" overlapping → "Already playing" w logach).
            if nsSound.isPlaying {
                nsSound.stop()
            }
            nsSound.play()
            Log.app.debug("Played sound: \(sound.rawValue, privacy: .public)")
        } else {
            Log.app.warning("System sound '\(sound.rawValue, privacy: .public)' not available")
        }
    }
}
