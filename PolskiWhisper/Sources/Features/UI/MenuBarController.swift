//
//  MenuBarController.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// Kontroler ikony aplikacji w pasku menu (NSStatusItem).
///
/// Stany ikony:
/// - **idle**: zwykła ikona mikrofonu
/// - **recording**: czerwona kropka (animowana w przyszłości)
/// - **processing**: ikona "kropki..." (Whisper lub LLM cleanup)
///
/// Menu (right-click lub click):
/// - Status (np. "Gotowy do dyktowania")
/// - "Otwórz Ustawienia" (Cmd+,)
/// - "O programie"
/// - Separator
/// - "Zakończ PolskiWhisper" (Cmd+Q)
@MainActor
final class MenuBarController {

    // MARK: - Properties

    private let statusItem: NSStatusItem
    private var phaseObservation: NSKeyValueObservation?
    private var cancellable: Any?

    // MARK: - Init

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        configureMenu()
        observePhase()
        Log.menuBar.info("MenuBarController initialized")
    }

    // MARK: - Configuration

    private func configureButton() {
        guard let button = statusItem.button else {
            Log.menuBar.error("Cannot get NSStatusItem button - menu bar may be unavailable")
            return
        }

        button.image = symbolImage(named: "mic")
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.toolTip = "PolskiWhisper - kliknij aby otworzyć menu"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Status header (disabled, informational)
        let statusItem = NSMenuItem(title: "Gotowy do dyktowania", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusItem.tag = MenuItemTag.status.rawValue
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Otwórz Ustawienia
        let settingsItem = NSMenuItem(
            title: "Otwórz Ustawienia...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)

        // O programie
        let aboutItem = NSMenuItem(
            title: "O programie PolskiWhisper",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Zakończ PolskiWhisper",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    // MARK: - Phase observation

    private func observePhase() {
        // AppCoordinator jest @Observable - używamy withObservationTracking dla manual observation
        observePhaseChange()
    }

    private func observePhaseChange() {
        withObservationTracking {
            // Trigger access to phase to register observer
            _ = AppCoordinator.shared.phase
        } onChange: {
            // onChange jest wywoływane jednorazowo - musimy re-register
            Task { @MainActor [weak self] in
                self?.updateForCurrentPhase()
                self?.observePhaseChange()  // re-register
            }
        }
        // Initial state
        updateForCurrentPhase()
    }

    /// Wymuś odświeżenie menu bar (np. po zmianie hotkey w Settings).
    func refresh() {
        updateForCurrentPhase()
    }

    private func updateForCurrentPhase() {
        guard let button = statusItem.button else { return }

        let phase = AppCoordinator.shared.phase

        switch phase {
        case .idle:
            // Idle ale sprawdź czy model jest gotowy do dyktowania
            if let engine = AppCoordinator.shared.dictationEngine,
               engine.whisperService.loadedModel == nil {
                if engine.whisperService.isLoading {
                    button.image = symbolImage(named: "arrow.down.circle")
                    let progress = Int(engine.whisperService.loadProgress * 100)
                    updateStatusItemText("Pobieranie modelu AI... \(progress)%")
                } else {
                    button.image = symbolImage(named: "mic.slash")
                    updateStatusItemText("Model AI nie załadowany")
                }
            } else {
                button.image = symbolImage(named: "mic")
                let hotkeyName = AppCoordinator.shared.selectedHotkey.displayName
                updateStatusItemText("Gotowy do dyktowania (\(hotkeyName))")
            }
        case .loadingModel:
            button.image = symbolImage(named: "arrow.down.circle")
            updateStatusItemText("Pobieranie/ładowanie modelu...")
        case .recording:
            button.image = symbolImage(named: "mic.fill")
            updateStatusItemText("Nagrywanie...")
        case .processingWhisper:
            button.image = symbolImage(named: "waveform")
            updateStatusItemText("Transkrypcja...")
        case .processingLLM:
            button.image = symbolImage(named: "sparkles")
            updateStatusItemText("Polerowanie tekstu...")
        case .pasting:
            button.image = symbolImage(named: "doc.on.clipboard")
            updateStatusItemText("Wklejanie...")
        case .completed(let length):
            button.image = symbolImage(named: "checkmark.circle")
            updateStatusItemText("Gotowe (\(length) znaków)")
        case .error(let message):
            button.image = symbolImage(named: "exclamationmark.triangle")
            updateStatusItemText("Błąd: \(message)")
        }
        button.image?.isTemplate = true
    }

    private func updateStatusItemText(_ text: String) {
        guard let menu = statusItem.menu,
              let item = menu.item(withTag: MenuItemTag.status.rawValue) else { return }
        item.title = text
    }

    // MARK: - Helpers

    /// Tworzy NSImage z SF Symbol z fallbackiem na text jeśli symbol niedostępny.
    private func symbolImage(named name: String) -> NSImage? {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: name) {
            return image
        }
        Log.menuBar.warning("SF Symbol '\(name, privacy: .public)' niedostępny, używam fallback")
        return NSImage(named: NSImage.Name("AppIcon"))
    }

    // MARK: - Actions

    @objc private func openSettings() {
        Log.menuBar.info("Opening settings from menu")
        SettingsWindowController.shared.show()
    }

    @objc private func showAbout() {
        Log.menuBar.info("Showing About panel")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - Tags

    private enum MenuItemTag: Int {
        case status = 100
    }
}
