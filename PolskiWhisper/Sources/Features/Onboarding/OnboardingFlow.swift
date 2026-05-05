//
//  OnboardingFlow.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import AVFoundation
import SwiftUI

/// Flow przy pierwszym uruchomieniu aplikacji - prowadzi użytkownika przez:
/// 1. Powitanie + opis
/// 2. Uprawnienia mikrofonu (request)
/// 3. Uprawnienia Accessibility (open System Settings + verify)
/// 4. Model Whisper (status + opcja pobrania)
/// 5. Info o hotkey (Left Option toggle)
/// 6. Gotowe!
///
/// Pokazywany przez AppDelegate jeśli `AppCoordinator.shared.onboardingCompleted == false`.
/// Po zakończeniu ustawia onboardingCompleted = true.
@MainActor
final class OnboardingFlow {

    static let shared = OnboardingFlow()

    private var window: NSWindow?
    private var hostingController: NSHostingController<OnboardingRootView>?

    private init() {}

    /// Pokazuje okno onboardingu (z poziomu menu bar app aktywuje aplikację).
    func show() {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = OnboardingRootView(onComplete: { [weak self] in
            self?.complete()
        })
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 640, height: 520)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PolskiWhisper - Konfiguracja"
        window.contentViewController = hosting
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        self.hostingController = hosting

        NSApp.setActivationPolicy(.regular)  // pokaż w Dock podczas onboardingu
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        Log.app.info("Onboarding flow shown")
    }

    /// Zamyka onboarding, ustawia flag completed, wraca do trybu zgodnego z Settings.
    func complete() {
        AppCoordinator.shared.onboardingCompleted = true
        window?.close()
        window = nil
        hostingController = nil

        // Apply Dock visibility z Settings (.regular jeśli showInDock, .accessory jeśli nie)
        AppCoordinator.shared.applyDockVisibility(AppCoordinator.shared.showInDock)

        // FIX: NSStatusItem może być w broken state po activation policy change.
        // Re-create menu bar controller żeby ikona pojawiła się poprawnie.
        AppCoordinator.shared.menuBarController = nil
        AppCoordinator.shared.menuBarController = MenuBarController()

        Log.app.info("Onboarding completed - menu bar mode + Dock=\(AppCoordinator.shared.showInDock, privacy: .public)")
    }
}

// MARK: - Steps enum

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case whisperModel
    case hotkey
    case done

    var title: String {
        switch self {
        case .welcome: return "Witaj w PolskiWhisper"
        case .microphone: return "Dostęp do mikrofonu"
        case .accessibility: return "Uprawnienie Dostępności"
        case .whisperModel: return "Model AI"
        case .hotkey: return "Skrót klawiszowy"
        case .done: return "Wszystko gotowe!"
        }
    }
}

// MARK: - Root view

struct OnboardingRootView: View {
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            // Header z postępem
            VStack(spacing: 8) {
                ProgressView(
                    value: Double(currentStep.rawValue),
                    total: Double(OnboardingStep.allCases.count - 1)
                )
                .progressViewStyle(.linear)
                .tint(.accentColor)
                Text("Krok \(currentStep.rawValue + 1) z \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Step content
            Group {
                switch currentStep {
                case .welcome: WelcomeStepView(next: nextStep)
                case .microphone: MicrophoneStepView(next: nextStep)
                case .accessibility: AccessibilityStepView(next: nextStep)
                case .whisperModel: WhisperModelStepView(next: nextStep)
                case .hotkey: HotkeyStepView(next: nextStep)
                case .done: DoneStepView(complete: onComplete)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
        }
    }

    private func nextStep() {
        let nextRaw = currentStep.rawValue + 1
        if let next = OnboardingStep(rawValue: nextRaw) {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep = next
            }
        } else {
            onComplete()
        }
    }
}

// MARK: - Step views

private struct WelcomeStepView: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("🎤 Witaj w PolskiWhisper")
                .font(.largeTitle)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                Text("Natywna macOS aplikacja do promptowania głosowego po polsku.")
                    .multilineTextAlignment(.center)
                Text("Naciskasz lewy Option lub inny wybrany klawisz, mówisz, naciskasz klawisz ponownie - tekst wkleja się w aktywnej aplikacji. Wszystko offline, na Twoim komputerze.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            Spacer()

            Button("Zaczynajmy") { next() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct MicrophoneStepView: View {
    let next: () -> Void
    @State private var status: PermissionsHelper.MicrophoneStatus = PermissionsHelper.microphoneStatus
    @State private var requesting: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: status == .authorized ? "checkmark.circle.fill" : "mic")
                .font(.system(size: 64))
                .foregroundStyle(status == .authorized ? Color.green : Color.accentColor)

            Text("Dostęp do mikrofonu")
                .font(.title)
                .fontWeight(.semibold)

            Text("Aplikacja potrzebuje dostępu do mikrofonu aby nagrywać Twój głos. Audio jest przetwarzane lokalnie i nigdy nie opuszcza Twojego komputera.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            statusView

            Spacer()

            HStack(spacing: 12) {
                if status != .authorized {
                    Button {
                        requestAccess()
                    } label: {
                        if requesting {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text("Zezwól na dostęp")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(requesting)
                } else {
                    Button("Dalej") { next() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear {
            status = PermissionsHelper.microphoneStatus
        }
    }

    @ViewBuilder
    private var statusView: some View {
        HStack {
            switch status {
            case .authorized:
                Label("Dostęp przyznany", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                VStack(alignment: .leading, spacing: 4) {
                    Label("Dostęp odmówiony", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Button("Otwórz Ustawienia systemu") {
                        PermissionsHelper.openMicrophoneSettings()
                    }
                    .buttonStyle(.link)
                }
            case .notDetermined:
                Label("Nie pytano jeszcze o dostęp", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            case .restricted:
                Label("Dostęp ograniczony przez system", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }

    private func requestAccess() {
        requesting = true
        Task {
            _ = await PermissionsHelper.requestMicrophoneAccess()
            await MainActor.run {
                status = PermissionsHelper.microphoneStatus
                requesting = false
                if status == .authorized {
                    next()
                }
            }
        }
    }
}

private struct AccessibilityStepView: View {
    let next: () -> Void
    @State private var isGranted: Bool = PermissionsHelper.isAccessibilityGranted

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "keyboard")
                .font(.system(size: 64))
                .foregroundStyle(isGranted ? Color.green : Color.accentColor)

            Text("Uprawnienie Dostępności")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("Aplikacja potrzebuje uprawnienia **Dostępność** aby:")
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 4) {
                    Label("Wykrywać naciśnięcie skrótu (lewy Option)", systemImage: "1.circle.fill")
                    Label("Symulować Cmd+V do auto-wklejania", systemImage: "2.circle.fill")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if !isGranted {
                VStack(spacing: 8) {
                    Text("Otwórz **Ustawienia systemu → Prywatność i ochrona → Dostępność** i włącz przełącznik dla PolskiWhisper.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Otwórz Ustawienia") {
                        PermissionsHelper.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            } else {
                Label("Uprawnienie przyznane", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            Spacer()

            HStack(spacing: 12) {
                if isGranted {
                    Button("Dalej") { next() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Sprawdź ponownie") {
                        checkPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Pomiń") { next() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
        }
        .onAppear { checkPermission() }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            checkPermission()
        }
    }

    private func checkPermission() {
        let granted = PermissionsHelper.isAccessibilityGranted
        if granted != isGranted {
            isGranted = granted
            // Jeśli właśnie przyznano - re-init hotkey monitor
            if granted {
                AppCoordinator.shared.startHotkeyMonitor()
            }
        }
    }
}

private struct WhisperModelStepView: View {
    let next: () -> Void

    @State private var coordinator = AppCoordinator.shared

    private var whisperService: WhisperService? {
        coordinator.dictationEngine?.whisperService
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: whisperService?.loadedModel != nil ? "checkmark.circle.fill" : "waveform")
                .font(.system(size: 64))
                .foregroundStyle(whisperService?.loadedModel != nil ? Color.green : Color.accentColor)

            Text("Model AI")
                .font(.title)
                .fontWeight(.semibold)

            if let service = whisperService, let model = service.loadedModel {
                VStack(spacing: 8) {
                    Text("Model gotowy do użycia:")
                        .foregroundStyle(.secondary)
                    Text(model.displayName)
                        .font(.callout)
                        .fontWeight(.medium)
                }
            } else if let service = whisperService, service.isLoading {
                VStack(spacing: 12) {
                    Text("Pobieranie modelu \(WhisperService.Model.default.rawValue)...")
                        .foregroundStyle(.secondary)
                    Text("To może zająć 1-2 minuty (~547 MB).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 300)
                }
            } else {
                Text("Aplikacja używa Whisper Turbo (optymalizowany pod polski). Model zostanie pobrany z Hugging Face przy pierwszym uruchomieniu (~547 MB).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Spacer()

            Button("Dalej") { next() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct HotkeyStepView: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "command")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Skrót klawiszowy")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                Text("Domyślny skrót do dyktowania:")
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    keycap("⌥")
                    Text("(lewy)")
                        .foregroundStyle(.secondary)
                }

                Text("Naciśnij krótko (tap) aby rozpocząć nagrywanie. Naciśnij ponownie aby zakończyć - tekst zostanie wklejony w aktywnej aplikacji.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .font(.callout)

                Text("Skrót można zmienić w Ustawieniach (Cmd+,)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Dalej") { next() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .semibold, design: .rounded))
            .frame(minWidth: 56, minHeight: 56)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

private struct DoneStepView: View {
    let complete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Wszystko gotowe!")
                .font(.largeTitle)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                Text("Aplikacja jest skonfigurowana i gotowa do użycia.")
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Otwórz Notatki lub dowolne pole tekstowe", systemImage: "1.circle.fill")
                    Label("Naciśnij krótko **lewy Option**", systemImage: "2.circle.fill")
                    Label("Mów po polsku", systemImage: "3.circle.fill")
                    Label("Naciśnij **lewy Option** ponownie", systemImage: "4.circle.fill")
                    Label("Tekst wklei się automatycznie", systemImage: "5.circle.fill")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                Button("Rozpocznij dyktowanie") { complete() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

                Text("Aplikacja działa w pasku menu (ikona mikrofonu w prawym górnym rogu).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
