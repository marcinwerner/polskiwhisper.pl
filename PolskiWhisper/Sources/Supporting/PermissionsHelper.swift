//
//  PermissionsHelper.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AVFoundation
import AppKit
import ApplicationServices
import Foundation

/// Helper dla sprawdzania i requestowania uprawnień systemowych.
///
/// PolskiWhisper wymaga dwóch uprawnień:
/// 1. **Mikrofon** - do nagrywania audio (privacy permission, request via API)
/// 2. **Accessibility** - do globalnego hotkey i auto-paste Cmd+V (system permission, manual grant)
@MainActor
enum PermissionsHelper {

    // MARK: - Microphone

    enum MicrophoneStatus {
        case authorized
        case denied
        case notDetermined
        case restricted

        init(_ status: AVAuthorizationStatus) {
            switch status {
            case .authorized: self = .authorized
            case .denied: self = .denied
            case .restricted: self = .restricted
            case .notDetermined: self = .notDetermined
            @unknown default: self = .denied
            }
        }
    }

    static var microphoneStatus: MicrophoneStatus {
        MicrophoneStatus(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    /// Request microphone access. Wyświetla system prompt jeśli `.notDetermined`.
    static func requestMicrophoneAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        Log.permissions.info("Microphone access: \(granted ? "granted" : "denied", privacy: .public)")
        return granted
    }

    /// Otwiera System Settings → Privacy & Security → Microphone.
    static func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Accessibility

    /// Sprawdza czy aplikacja ma uprawnienie Accessibility (wymagane dla CGEventTap i CGEvent.post).
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Sprawdza Accessibility z opcjonalnym requestem (pokazuje system prompt).
    /// Zwraca aktualny status (może być false nawet po prompt - user musi sam włączyć w Settings).
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ]
        let granted = AXIsProcessTrustedWithOptions(options)
        Log.permissions.info("Accessibility access: \(granted ? "granted" : "denied", privacy: .public)")
        return granted
    }

    /// Otwiera System Settings → Privacy & Security → Accessibility.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Comprehensive check

    struct PermissionStatus {
        let microphone: MicrophoneStatus
        let accessibility: Bool

        var allGranted: Bool {
            microphone == .authorized && accessibility
        }

        var missingPermissions: [String] {
            var missing: [String] = []
            if microphone != .authorized { missing.append("Mikrofon") }
            if !accessibility { missing.append("Accessibility") }
            return missing
        }
    }

    static var currentStatus: PermissionStatus {
        PermissionStatus(
            microphone: microphoneStatus,
            accessibility: isAccessibilityGranted
        )
    }
}
