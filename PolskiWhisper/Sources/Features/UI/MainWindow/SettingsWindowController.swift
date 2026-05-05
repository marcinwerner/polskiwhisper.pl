//
//  SettingsWindowController.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import SwiftUI

/// Manualny controller dla okna Ustawień - omija ostrzeżenie macOS 14+
/// "Please use SettingsLink for opening the Settings scene".
///
/// W menu bar app (LSUIElement = true) otwarcie SwiftUI Settings scene z NSStatusItem
/// jest problematyczne - Apple zaleca SettingsLink ale ten działa tylko w SwiftUI views.
/// Workaround: własny NSWindow z NSHostingController(SettingsView()).
@MainActor
final class SettingsWindowController {

    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?

    private init() {}

    /// Pokazuje okno Ustawień. Jeśli już otwarte - przywołuje na wierzch.
    /// Obsługuje edge cases: zminimalizowane okno (deminiaturize), inny desktop, w tle.
    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        hosting.view.frame = NSRect(x: 0, y: 0, width: 720, height: 520)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ustawienia PolskiWhisper"
        window.contentViewController = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = SettingsWindowDelegate.shared

        self.window = window
        self.hostingController = hosting

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        Log.ui.info("Settings window shown")
    }

    /// Wywoływane przez delegate po close - czyści referencję żeby kolejne show() utworzyło fresh window.
    func windowDidClose() {
        window = nil
        hostingController = nil
        Log.ui.info("Settings window closed")
    }
}

// MARK: - Window delegate

@MainActor
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        SettingsWindowController.shared.windowDidClose()
    }
}
