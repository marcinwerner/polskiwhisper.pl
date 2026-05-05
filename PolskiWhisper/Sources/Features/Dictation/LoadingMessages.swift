//
//  LoadingMessages.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import Observation

/// Rotujące komunikaty dla UI podczas długiego pierwszego loadu modelu.
///
/// Pierwsza inicjalizacja Whispera trwa 2-3 min (download 1.5 GB + ANE compile).
/// User widzi tylko spinner/pasek - bez info co się dzieje może pomyśleć że aplikacja
/// się zawiesiła. Rotujące komunikaty co 5s pokazują że proces postępuje + reassurance
/// że to jednorazowo.
///
/// Komunikaty są stable per faza (downloading vs loadingToRAM) - rotujemy w obrębie fazy.
@MainActor
@Observable
final class LoadingMessages {

    static let shared = LoadingMessages()

    /// Aktualny komunikat - obserwowany przez SwiftUI views.
    private(set) var currentMessage: String = ""

    /// Aktualna faza dla której rotujemy komunikaty.
    private var currentPhase: WhisperService.LoadPhase = .idle

    /// Index aktualnego komunikatu w aktywnej liście.
    private var messageIndex: Int = 0

    /// Timer rotujący komunikaty co 5s.
    private var rotationTimer: Timer?

    private init() {}

    // MARK: - Komunikaty per faza

    private static let downloadingMessages: [String] = [
        "Pobieranie modelu Whisper Turbo (1.5 GB) z HuggingFace...",
        "To się dzieje tylko podczas pierwszego uruchomienia aplikacji",
        "Po pobraniu model zostanie zapisany lokalnie",
        "Pobieranie raz - reszta będzie błyskawiczna"
    ]

    private static let loadingToRAMMessages: [String] = [
        "Przygotowywanie modelu dla Twojego Maca...",
        "Apple Neural Engine kompiluje model - jednorazowo",
        "Konwersja warstw CoreML do formatu Neural Engine",
        "Optymalizacja dla Twojego procesora",
        "Po tym pierwszym razie wszystko będzie szybkie",
        "Każde kolejne uruchomienie aplikacji zajmie moment",
        "Każda transkrypcja po starcie ~1.5s",
        "Ładowanie wag modelu do pamięci...",
        "Już prawie gotowe..."
    ]

    // MARK: - Public API

    /// Wywoływane gdy WhisperService.loadPhase się zmienia.
    /// Aktualizuje aktywną listę komunikatów + restartuje timer.
    func update(phase: WhisperService.LoadPhase) {
        // Sprawdź czy faza się rzeczywiście zmieniła (różne case z associated values)
        let phaseKey = Self.phaseKey(phase)
        let oldKey = Self.phaseKey(currentPhase)

        if phaseKey != oldKey {
            currentPhase = phase
            messageIndex = 0
            updateMessage()

            // Restartuj timer dla nowej fazy (lub stop jeśli idle/ready)
            stopTimer()
            switch phase {
            case .downloading, .loadingToRAM:
                startTimer()
            case .idle, .ready:
                currentMessage = ""
            }
        } else {
            currentPhase = phase  // update wartości w obrębie tego samego case
        }
    }

    // MARK: - Internal

    private func startTimer() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advance()
            }
        }
    }

    private func stopTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    private func advance() {
        let messages = currentMessages()
        guard !messages.isEmpty else { return }
        messageIndex = (messageIndex + 1) % messages.count
        updateMessage()
    }

    private func updateMessage() {
        let messages = currentMessages()
        guard !messages.isEmpty else {
            currentMessage = ""
            return
        }
        currentMessage = messages[messageIndex % messages.count]
    }

    private func currentMessages() -> [String] {
        switch currentPhase {
        case .downloading: return Self.downloadingMessages
        case .loadingToRAM: return Self.loadingToRAMMessages
        case .idle, .ready: return []
        }
    }

    /// String key dla porównania faz (ignoruje associated values).
    private static func phaseKey(_ phase: WhisperService.LoadPhase) -> String {
        switch phase {
        case .idle: return "idle"
        case .downloading: return "downloading"
        case .loadingToRAM: return "loadingToRAM"
        case .ready: return "ready"
        }
    }
}
