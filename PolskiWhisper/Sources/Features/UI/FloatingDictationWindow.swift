//
//  FloatingDictationWindow.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import SwiftUI

/// Pływające okno dyktowania - widoczne podczas nagrywania i processingu.
///
/// Specyfikacja (ADR-010):
/// - **Poziom**: `.statusBar` (CGShieldingWindowLevel - 1) - widoczne nad fullscreen apps
/// - **Rozmiar**: ~280 x 60 px
/// - **Tło**: NSVisualEffectView vibrancy (.hudWindow)
/// - **Pozycja**: środek ekranu, dolna część (100 px nad dolną krawędzią)
/// - **Animacje**: scale + fade enter (300ms), scale + fade exit (200ms)
@MainActor
final class FloatingDictationWindow {

    // MARK: - Properties

    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingDictationContent>?

    // MARK: - Public API

    /// Czy okno jest aktualnie widoczne.
    var isVisible: Bool {
        panel != nil
    }

    /// Pokazuje okno z animacją scale + fade in.
    func show() {
        if panel != nil {
            // już pokazane
            return
        }

        let panel = createPanel()
        let content = FloatingDictationContent()
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = hostingView

        positionPanel(panel)

        // Initial state for animation
        panel.alphaValue = 0
        panel.animator().alphaValue = 0
        panel.orderFront(nil)

        self.panel = panel
        self.hostingView = hostingView

        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        Log.ui.info("FloatingDictationWindow shown")
    }

    /// Ukrywa okno z animacją fade out.
    func hide() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
                self?.hostingView = nil
                Log.ui.info("FloatingDictationWindow hidden")
            }
        })
    }

    // MARK: - Private

    private func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar  // ADR-010: nad fullscreen apps
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true  // HUD - user nie może kliknąć przypadkowo

        // Transparent background, content view (SwiftUI) ma własne tło
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false

        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame

        // Center horizontally, 50px under menu bar (góra ekranu - jak Superwhisper).
        // visibleFrame.maxY = top of usable area (poniżej menu bar).
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.maxY - panelFrame.height - 50

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI content

/// Zawartość pływającego okna - obserwuje AppCoordinator i AudioRecorder dla aktualizacji.
struct FloatingDictationContent: View {

    @State private var coordinator = AppCoordinator.shared
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    /// Real-time peaks z AudioRecorder. SwiftUI auto re-renders przy każdym update
    /// (recentPeaks jest observable property w @Observable AudioRecorder).
    private var audioPeaks: [Float] {
        coordinator.dictationEngine?.audioRecorder.recentPeaks ?? []
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                // Left: status icon
                phaseIcon
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(phaseColor)

                // Center: real-time waveform (80 bars scrolling)
                WaveformView(samples: audioPeaks)
                    .frame(maxWidth: .infinity)

                // Right: timer + status
                Text(timerText)
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 280, height: 60)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var phaseIcon: some View {
        switch coordinator.phase {
        case .idle:
            Image(systemName: "mic")
        case .loadingModel:
            Image(systemName: "arrow.down.circle")
                .symbolEffect(.pulse, options: .repeating)
        case .recording:
            Image(systemName: "mic.fill")
                .symbolEffect(.pulse, options: .repeating)
        case .processingWhisper:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor, options: .repeating)
        case .pasting:
            Image(systemName: "doc.on.clipboard")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var phaseColor: Color {
        switch coordinator.phase {
        case .idle: return .secondary
        case .loadingModel: return .orange
        case .recording: return .red
        case .processingWhisper: return .blue
        case .pasting: return .green
        case .completed: return .green
        case .error: return .red
        }
    }

    private var timerText: String {
        switch coordinator.phase {
        case .loadingModel:
            return "Ładowanie..."
        case .recording:
            return formatTime(elapsedSeconds)
        case .processingWhisper:
            return "Tekst"
        case .pasting:
            return "..."
        case .completed:
            return "OK"
        case .error:
            return "!"
        case .idle:
            return ""
        }
    }

    // MARK: - Timer

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if case .recording = coordinator.phase {
                    elapsedSeconds += 1
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Visual effect wrapper

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
