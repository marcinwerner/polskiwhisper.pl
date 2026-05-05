//
//  ModifierKeyMonitor.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Carbon.HIToolbox
import Foundation

/// Monitor "tap" eventów dla pojedynczych klawiszy modyfikatorów (Left Option, Right Option, Fn).
///
/// Standardowe `KeyboardShortcuts` library obsługuje **kombinacje** (Cmd+Shift+X) ale NIE pojedyncze
/// modyfikatory. Ten monitor uzupełnia to przez `NSEvent.addGlobalMonitorForEvents`.
///
/// Detekcja "tap":
/// 1. User naciska klawisz modyfikatora (np. Left Option) → flag goes ON
/// 2. User puszcza klawisz (BEZ wciskania innych klawiszy w międzyczasie) → flag goes OFF
/// 3. Czas między ON i OFF < 500ms → to jest "tap" → fire callback
///
/// Jeśli user wciśnie inny klawisz w międzyczasie (np. Option+Strzałka), to NIE jest tap - ignorujemy.
@MainActor
final class ModifierKeyMonitor {

    // MARK: - Targets

    enum Key {
        case leftOption
        case rightOption
        case leftCommand
        case rightCommand
        case leftShift
        case rightShift
        case leftControl
        case rightControl
        case fn

        /// CGEventFlags maska dla tej kombinacji.
        var flag: CGEventFlags {
            switch self {
            case .leftOption, .rightOption: return .maskAlternate
            case .leftCommand, .rightCommand: return .maskCommand
            case .leftShift, .rightShift: return .maskShift
            case .leftControl, .rightControl: return .maskControl
            case .fn: return .maskSecondaryFn
            }
        }

        /// Maska device-independent flag (z NSEvent.modifierFlags).
        var deviceMask: NSEvent.ModifierFlags {
            switch self {
            case .leftOption, .rightOption: return .option
            case .leftCommand, .rightCommand: return .command
            case .leftShift, .rightShift: return .shift
            case .leftControl, .rightControl: return .control
            case .fn: return .function
            }
        }

        /// Side-specific flag bit (z NSEvent flags raw value).
        /// Reference: https://developer.apple.com/documentation/coregraphics/cgeventflags
        var deviceFlag: UInt {
            switch self {
            case .leftShift: return 0x00020002
            case .rightShift: return 0x00020004
            case .leftControl: return 0x00040001
            case .rightControl: return 0x00042000
            case .leftOption: return 0x00080020
            case .rightOption: return 0x00080040
            case .leftCommand: return 0x00100008
            case .rightCommand: return 0x00100010
            // Fn: NSEventModifierFlagFunction (1 << 23 = 0x00800000) bez device-specific bitów.
            // Wcześniejsze 0x00800100 było błędne - na większości MacBooków powodowało brak detekcji.
            case .fn: return 0x00800000
            }
        }
    }

    // MARK: - Mode

    enum Mode {
        /// Tap detection - tap (krótkie naciśnięcie) trigger callback.
        case toggle
        /// Hold detection - press start callback, release stop callback (push-to-talk).
        case hold
    }

    // MARK: - Properties

    private let target: Key
    private let mode: Mode
    private let onTap: () -> Void
    private let onHoldStart: () -> Void
    private let onHoldEnd: () -> Void

    /// Maximum time between key down and key up to count as "tap" (instead of hold).
    private let tapMaxDuration: TimeInterval = 0.5
    /// Minimum hold duration before triggering onHoldStart (chroni przed przypadkowym).
    private let holdMinDuration: TimeInterval = 0.05

    private var monitor: Any?
    private var localMonitor: Any?
    private var keyDownTime: Date?
    private var otherKeyPressedDuringTap: Bool = false
    private var holdActive: Bool = false

    // MARK: - Init

    /// - Parameters:
    ///   - target: który klawisz modyfikatora monitorować
    ///   - mode: toggle (tap detection) lub hold (push-to-talk)
    ///   - onTap: callback wywoływany w trybie toggle
    ///   - onHoldStart: callback wywoływany w trybie hold gdy klawisz jest przytrzymany
    ///   - onHoldEnd: callback wywoływany w trybie hold gdy klawisz jest puszczony
    init(
        target: Key,
        mode: Mode = .toggle,
        onTap: @escaping () -> Void = {},
        onHoldStart: @escaping () -> Void = {},
        onHoldEnd: @escaping () -> Void = {}
    ) {
        self.target = target
        self.mode = mode
        self.onTap = onTap
        self.onHoldStart = onHoldStart
        self.onHoldEnd = onHoldEnd
    }

    deinit {
        // Cleanup w explicit `stop()` - deinit nie może bezpiecznie dotykać
        // @MainActor properties (nonisolated deinit w Swift 6).
        // Caller MUSI wywołać stop() przed dealokacją (robi to AppDelegate.applicationWillTerminate).
    }

    // MARK: - Public API

    /// Rozpoczyna monitoring. Wymaga uprawnienia Accessibility.
    /// Zwraca `false` jeśli accessibility nie jest granted (callback nie zostanie wywołany).
    @discardableResult
    func start() -> Bool {
        guard PermissionsHelper.isAccessibilityGranted else {
            Log.hotkey.error("Cannot start ModifierKeyMonitor - Accessibility not granted")
            return false
        }

        // Global monitor (events when our app is NOT active)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }

        // Local monitor (events when our app IS active - for completeness)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }

        Log.hotkey.info("ModifierKeyMonitor started for \(String(describing: self.target), privacy: .public)")
        return true
    }

    /// Zatrzymuje monitoring.
    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        Log.hotkey.info("ModifierKeyMonitor stopped")
    }

    // MARK: - Event handling

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleFlagsChange(event)
        case .keyDown:
            // Inny klawisz wciśnięty - to znaczy że Option+inne, NIE jest tap-only
            if keyDownTime != nil {
                otherKeyPressedDuringTap = true
            }
        default:
            break
        }
    }

    private func handleFlagsChange(_ event: NSEvent) {
        let rawFlags = UInt(event.modifierFlags.rawValue)
        let isTargetDown = (rawFlags & target.deviceFlag) == target.deviceFlag

        if isTargetDown {
            // Klawisz właśnie wciśnięty
            keyDownTime = Date()
            otherKeyPressedDuringTap = false

            // W trybie hold - rozpocznij hold po krótkiej delay (anti-bounce)
            if mode == .hold {
                let downTime = Date()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(Int(self?.holdMinDuration ?? 0.05) * 1000))
                    guard let self,
                          self.keyDownTime == downTime,
                          !self.holdActive,
                          !self.otherKeyPressedDuringTap else { return }
                    self.holdActive = true
                    Log.hotkey.info("Hold start on \(String(describing: self.target), privacy: .public)")
                    self.onHoldStart()
                }
            }
        } else {
            // Klawisz właśnie puszczony
            guard let downTime = keyDownTime else {
                // klawisz puszczony bez wciśnięcia (lub release flag z innego kontekstu)
                if holdActive {
                    holdActive = false
                    Log.hotkey.info("Hold end on \(String(describing: self.target), privacy: .public)")
                    onHoldEnd()
                }
                return
            }

            let duration = Date().timeIntervalSince(downTime)
            keyDownTime = nil

            let modifiersOtherThanTarget = event.modifierFlags
                .subtracting(target.deviceMask)
                .intersection([.command, .control, .shift, .option, .function])

            // W trybie hold - jeśli był aktywny, zakończ
            if mode == .hold {
                if holdActive {
                    holdActive = false
                    Log.hotkey.info("Hold end on \(String(describing: self.target), privacy: .public) (duration: \(duration, privacy: .public)s)")
                    onHoldEnd()
                } else if duration >= holdMinDuration {
                    // Hold nie był aktywny ale duration > min - może błąd timing.
                    // Nie wywołujemy callback (hold start się nie udał).
                }
                return
            }

            // Tryb toggle - tap detection
            let isTap = duration < tapMaxDuration
                && !otherKeyPressedDuringTap
                && modifiersOtherThanTarget.isEmpty

            if isTap {
                Log.hotkey.info("Tap detected on \(String(describing: self.target), privacy: .public) (duration: \(duration, privacy: .public)s)")
                onTap()
            } else {
                Log.hotkey.debug("Modifier release (not a tap): duration=\(duration, privacy: .public), otherKeys=\(self.otherKeyPressedDuringTap, privacy: .public)")
            }
        }
    }
}
