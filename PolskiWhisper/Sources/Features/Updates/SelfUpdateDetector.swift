//
//  SelfUpdateDetector.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Foundation
import Observation

/// Wykrywa gdy ktoś podmienił `.app` w `/Applications/` (user pobrał DMG i przeciągnął
/// do Applications, replace, ale nie zrestartował aplikacji).
///
/// Mechanizm: porównuje executable mtime nagranego przy starcie z aktualnym.
/// Sprawdza co 60s. Jeśli mtime się zmienił → mtime różny od baseline = ktoś podmienił.
///
/// UX: pierwszy detekcja → modal alert "Wykryto nową wersję, zrestartować?". Dalsze
/// detekcje (jeśli user kliknie Później) → menu bar badge z buttonem Restart.
@MainActor
@Observable
final class SelfUpdateDetector {

    static let shared = SelfUpdateDetector()

    /// Czy została wykryta podmiana .app (i restart nadal nie wykonany).
    private(set) var restartRequired: Bool = false

    /// mtime executable w czasie startu aplikacji - baseline do porównania.
    private let baselineMtime: Date?

    /// Timer do okresowego check (co 60s).
    private var checkTimer: Timer?

    /// Czy user już widział modal (żeby nie spamować) - po pierwszej detekcji
    /// kolejne updateRestartRequired tylko aktualizują badge, bez modal.
    private var modalShown: Bool = false

    private init() {
        self.baselineMtime = Self.executableMtime()
        Log.app.info("SelfUpdateDetector: baseline mtime = \(String(describing: self.baselineMtime), privacy: .public)")
    }

    // MARK: - Public API

    /// Rozpoczyna periodic check. Wywoływane raz przy starcie aplikacji.
    func startMonitoring() {
        guard checkTimer == nil else { return }
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForReplacement()
            }
        }
        Log.app.info("SelfUpdateDetector: monitoring started (60s interval)")
    }

    /// Restart aplikacji - uruchamia siebie na nowo i kończy aktualną instancję.
    /// Bez Apple Dev signing nie ma true silent restart - macOS może pokazać Gatekeeper
    /// dialog dla "unidentified developer", ale po pierwszym launch (Right Click → Open)
    /// kolejne uruchomienia są ciche.
    func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        Log.app.info("Relaunching app from: \(bundleURL.path, privacy: .public)")

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, error in
            if let error {
                Log.app.error("Failed to relaunch: \(error.localizedDescription, privacy: .public)")
                return
            }
            // Daj systemowi 1s na uruchomienie nowej instancji, potem zabij siebie
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Internal

    private func checkForReplacement() {
        guard let baseline = baselineMtime else { return }
        guard let current = Self.executableMtime() else { return }

        // Tolerancja 1 sek - nie reagujemy na drobne zmiany (touch).
        if abs(current.timeIntervalSince(baseline)) < 1.0 {
            return  // bez zmian
        }

        // Wykryto podmianę
        if !restartRequired {
            restartRequired = true
            Log.app.info("SelfUpdateDetector: app bundle replaced detected (baseline=\(baseline, privacy: .public), current=\(current, privacy: .public))")

            // Notify menu bar żeby pokazał badge
            AppCoordinator.shared.menuBarController?.refreshUpdateItems()

            // Modal alert tylko przy first detection
            if !modalShown {
                modalShown = true
                showRestartAlert()
            }
        }
    }

    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Wykryto nową wersję PolskiWhisper"
        alert.informativeText = """
            W /Applications/ została zainstalowana nowsza wersja aplikacji. Aktualnie używasz starej, działającej w pamięci.

            Zrestartować aplikację, aby użyć nowej wersji? (Możesz to zrobić później przez menu bar.)
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart aplikacji")
        alert.addButton(withTitle: "Później")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            relaunchApp()
        }
        // Jeśli "Później" - badge w menu bar zostaje, user może kliknąć kiedy chce.
    }

    private static func executableMtime() -> Date? {
        guard let path = Bundle.main.executablePath else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return attrs[.modificationDate] as? Date
    }
}
