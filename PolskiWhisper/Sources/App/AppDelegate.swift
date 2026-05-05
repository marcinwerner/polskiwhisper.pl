//
//  AppDelegate.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Foundation

/// AppDelegate dla menu bar app.
///
/// Aplikacja jest `LSUIElement = true` (Info.plist) co oznacza:
/// - Brak ikony w Docku
/// - Brak menu na pasku aplikacji domyślnie
/// - Cykl życia kontrolowany przez NSStatusItem (menu bar) i floating window
///
/// AppDelegate inicjalizuje wszystkie kluczowe serwisy w `applicationDidFinishLaunching`:
/// - Sprawdzenie uprawnień (mikrofon + accessibility)
/// - Request mikrofon jeśli notDetermined
/// - AppCoordinator.start() - inicjalizacja MenuBar, DictationEngine, HotkeyMonitor
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("PolskiWhisper launching - version \(self.appVersion, privacy: .public)")

        // Sprawdź uprawnienia (log only przy starcie)
        let status = PermissionsHelper.currentStatus
        Log.app.info("""
            Permissions: microphone=\(String(describing: status.microphone), privacy: .public), \
            accessibility=\(status.accessibility, privacy: .public)
            """)

        // Request microphone w tle jeśli notDetermined (system pokaże prompt)
        if status.microphone == .notDetermined {
            Task {
                let granted = await PermissionsHelper.requestMicrophoneAccess()
                Log.app.info("Microphone request result: \(granted, privacy: .public)")
            }
        }

        // Jeśli Accessibility nie granted - pokaż system prompt z dialogiem
        // "Open System Settings". To dodaje PolskiWhisper do listy Accessibility
        // (toggle OFF), user włącza, restart app.
        if !status.accessibility {
            Log.app.info("Triggering Accessibility prompt - check System Settings dialog")
            _ = PermissionsHelper.checkAccessibility(prompt: true)
        }

        // Init wszystkich serwisów (menu bar pojawi się natychmiast)
        AppCoordinator.shared.start()

        // Cleanup orphan recordings z poprzedniej sesji (jeśli crash)
        cleanupOrphanRecordings()

        // Onboarding przy pierwszym uruchomieniu
        if !AppCoordinator.shared.onboardingCompleted {
            Log.app.info("First launch - showing onboarding flow")
            OnboardingFlow.shared.show()
        }

        Log.app.info("PolskiWhisper launch sequence complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.info("PolskiWhisper terminating")

        // Stop hotkey monitor
        AppCoordinator.shared.hotkeyMonitor?.stop()

        // Cleanup recordings (best-effort)
        cleanupOrphanRecordings()
    }

    /// Aplikacja działa jako menu bar - NIE zamykać gdy ostatnie okno zostanie zamknięte.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// Usuwa orphan WAV files z `~/Library/Caches/PolskiWhisper/`.
    /// Crash recovery decyzja (ADR-011): w Etap 1 - po prostu usuwamy stare. W Etap 4
    /// dodamy UI pytania "znaleziono pending recording, retransribe czy usunąć".
    private func cleanupOrphanRecordings() {
        let orphans = AudioRecorder.findOrphanRecordings()
        guard !orphans.isEmpty else { return }

        Log.app.info("Found \(orphans.count, privacy: .public) orphan recording(s) - cleaning up")
        for url in orphans {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
