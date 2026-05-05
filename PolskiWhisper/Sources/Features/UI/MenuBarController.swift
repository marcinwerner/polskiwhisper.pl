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
/// - **processing**: ikona "kropki..." (Whisper transkrypcja)
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

        // Update available - placeholder, populated dynamically w refresh()
        let updateItem = NSMenuItem(
            title: "",
            action: #selector(openUpdatePage),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.tag = MenuItemTag.updateAvailable.rawValue
        updateItem.isHidden = true  // domyślnie ukryty - pokazuje się gdy jest update
        menu.addItem(updateItem)

        // Restart required - placeholder dla self-update detection (e6)
        let restartItem = NSMenuItem(
            title: "",
            action: #selector(restartApp),
            keyEquivalent: ""
        )
        restartItem.target = self
        restartItem.tag = MenuItemTag.restartRequired.rawValue
        restartItem.isHidden = true
        menu.addItem(restartItem)

        let updateSeparator = NSMenuItem.separator()
        updateSeparator.tag = MenuItemTag.updateSeparator.rawValue
        updateSeparator.isHidden = true
        menu.addItem(updateSeparator)

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
        observeUpdateChange()
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

    /// Obserwuje UpdateChecker.availableUpdate i SelfUpdateDetector.restartRequired,
    /// odświeża menu items gdy któryś się zmieni.
    private func observeUpdateChange() {
        withObservationTracking {
            _ = UpdateChecker.shared.availableUpdate
            _ = SelfUpdateDetector.shared.restartRequired
        } onChange: {
            Task { @MainActor [weak self] in
                self?.refreshUpdateItems()
                self?.observeUpdateChange()  // re-register
            }
        }
        // Initial state
        refreshUpdateItems()
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

    @objc private func openUpdatePage() {
        guard let url = UpdateChecker.shared.availableUpdate?.releaseNotesURL else { return }
        Log.menuBar.info("Opening update page from menu")
        NSWorkspace.shared.open(url)
    }

    @objc private func restartApp() {
        Log.menuBar.info("User clicked restart from menu - relaunching")
        SelfUpdateDetector.shared.relaunchApp()
    }

    // MARK: - Update items observation

    /// Wywoływane gdy zmieni się availableUpdate w UpdateChecker - pokazujemy/ukrywamy
    /// menu item "Aktualizacja dostępna".
    func refreshUpdateItems() {
        guard let menu = statusItem.menu else { return }

        let updateItem = menu.item(withTag: MenuItemTag.updateAvailable.rawValue)
        let restartItem = menu.item(withTag: MenuItemTag.restartRequired.rawValue)
        let separator = menu.item(withTag: MenuItemTag.updateSeparator.rawValue)

        let availableUpdate = UpdateChecker.shared.availableUpdate
        let restartNeeded = SelfUpdateDetector.shared.restartRequired

        if let update = availableUpdate {
            updateItem?.title = "🆕 Dostępna v\(update.version) - Otwórz GitHub"
            updateItem?.isHidden = false
        } else {
            updateItem?.isHidden = true
        }

        if restartNeeded {
            restartItem?.title = "🔄 Restart wymagany dla nowej wersji"
            restartItem?.isHidden = false
        } else {
            restartItem?.isHidden = true
        }

        separator?.isHidden = (availableUpdate == nil && !restartNeeded)
    }

    // MARK: - Tags

    private enum MenuItemTag: Int {
        case status = 100
        case updateAvailable = 101
        case restartRequired = 102
        case updateSeparator = 103
    }
}
