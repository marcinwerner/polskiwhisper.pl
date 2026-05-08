//
//  NotificationDispatcher.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import UserNotifications

/// Wysyła natywne macOS notifications gdy są ważne wydarzenia (np. dostępna aktualizacja).
/// User dostaje sygnał w notification center bez konieczności otwierania Settings.
///
/// **Zero personal data** w treści - tylko numer wersji.
/// **Permission request** jest delicate - prosimy o zgodę DOPIERO przy pierwszym evencie
/// (NIE przy starcie aplikacji), żeby user wiedział o co prosimy.
@MainActor
final class NotificationDispatcher {

    static let shared = NotificationDispatcher()

    /// Identifier kategorii dla naszych notifikacji - umożliwia user'owi uciszenie
    /// w System Settings → Notifications jeśli przeszkadzają.
    private static let updateCategory = "PolskiWhisperUpdate"

    private var permissionRequested = false

    private init() {}

    /// Wysyła notyfikację "Dostępna aktualizacja" (po raz pierwszy prosi o zgodę).
    func notifyUpdateAvailable(version: String) {
        Task {
            let granted = await ensurePermission()
            guard granted else {
                Log.app.info("Notification: user nie zezwolił - skip")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Dostępna nowa wersja PolskiWhisper"
            content.body = "Wersja \(version) jest gotowa do pobrania. Otwórz Ustawienia → Ogólne, aby zaktualizować."
            content.sound = .default
            content.categoryIdentifier = Self.updateCategory

            let request = UNNotificationRequest(
                identifier: "update-\(version)",
                content: content,
                trigger: nil  // od razu
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                Log.app.info("Notification: wysłano powiadomienie o aktualizacji v\(version, privacy: .public)")
            } catch {
                Log.app.warning("Notification: błąd wysyłania - \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Private

    /// Pyta o zgodę na notyfikacje (przy pierwszym evencie, lazily).
    /// Zwraca true jeśli zgoda już była LUB user właśnie zezwolił.
    private func ensurePermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            // Pierwsza prośba - pokażemy system dialog
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                Log.app.info("Notification: permission request granted=\(granted, privacy: .public)")
                return granted
            } catch {
                Log.app.warning("Notification: permission request error - \(error.localizedDescription, privacy: .public)")
                return false
            }
        @unknown default:
            return false
        }
    }
}
