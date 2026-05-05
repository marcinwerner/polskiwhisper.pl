//
//  PasteService.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Carbon.HIToolbox
import Foundation

/// Wkleja tekst do aktywnej aplikacji przez schowek + symulację Cmd+V.
///
/// Sekwencja:
/// 1. Zapisuje poprzednią zawartość schowka (do restore opcjonalnie - obecnie nie używamy)
/// 2. Ustawia tekst w `NSPasteboard.general`
/// 3. Symuluje Cmd+V przez `CGEvent.post`
///
/// Wymaga uprawnienia **Accessibility** (sprawdzone wcześniej w `PermissionsHelper`).
@MainActor
final class PasteService {

    // MARK: - Errors

    enum PasteError: LocalizedError {
        case accessibilityNotGranted
        case clipboardWriteFailed
        case eventCreationFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityNotGranted:
                return "Brak uprawnienia Accessibility - nie mogę wkleić tekstu automatycznie. Tekst jest w schowku, wklej ręcznie (Cmd+V)."
            case .clipboardWriteFailed:
                return "Nie udało się zapisać tekstu do schowka."
            case .eventCreationFailed:
                return "Nie udało się utworzyć eventu klawiatury."
            }
        }
    }

    // MARK: - Public API

    /// Wkleja tekst w aktywnej aplikacji.
    ///
    /// - Parameter text: tekst do wklejenia (nie powinien być pusty - sprawdza caller)
    /// - Throws: `PasteError` jeśli paste się nie powiedzie
    ///
    /// Zachowanie:
    /// - Zawsze ustawia tekst w schowku (nawet jeśli auto-paste się nie powiedzie)
    /// - Symuluje Cmd+V tylko jeśli accessibility granted
    /// - Krótkie opóźnienie ~50ms między schowkiem a Cmd+V (synchronizacja)
    func paste(_ text: String) throws {
        guard !text.isEmpty else {
            Log.paste.warning("Attempted to paste empty text - skipping")
            return
        }

        // Krok 1: zapisz do schowka
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        guard success else {
            Log.paste.error("Failed to write to NSPasteboard")
            throw PasteError.clipboardWriteFailed
        }

        Log.paste.info("Text saved to clipboard (length: \(text.count, privacy: .public))")

        // Krok 2: symulacja Cmd+V (wymaga Accessibility)
        guard PermissionsHelper.isAccessibilityGranted else {
            Log.paste.warning("Accessibility not granted - text in clipboard, user must paste manually")
            throw PasteError.accessibilityNotGranted
        }

        // Krótkie opóźnienie żeby system zdążył zsynchronizować schowek
        // (empirycznie 50ms wystarcza, niżej bywa flaky w niektórych aplikacjach)
        Thread.sleep(forTimeInterval: 0.05)

        try simulateCmdV()
        Log.paste.info("Cmd+V simulated successfully")
    }

    // MARK: - Private

    /// Symuluje wciśnięcie Cmd+V (key code V = 9 na ANSI keyboard).
    ///
    /// Używa `.cghidEventTap` - wyższy poziom niż `.cgSessionEventTap`, eventy idą
    /// do HID layer co naśladuje fizyczne wciśnięcie klawisza. To jest poziom którego
    /// używa Superwhisper i podobne aplikacje - bardziej niezawodne w macOS 14+.
    private func simulateCmdV() throws {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        ) else {
            throw PasteError.eventCreationFailed
        }

        guard let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        ) else {
            throw PasteError.eventCreationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // .cghidEventTap = HID layer (najwyższy), bardziej niezawodne niż .cgSessionEventTap
        keyDown.post(tap: .cghidEventTap)
        // Mała przerwa między keyDown i keyUp - niektóre apps wymagają (Terminal, etc.)
        Thread.sleep(forTimeInterval: 0.01)
        keyUp.post(tap: .cghidEventTap)
    }
}
