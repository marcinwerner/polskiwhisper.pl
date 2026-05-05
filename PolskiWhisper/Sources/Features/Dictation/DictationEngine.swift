//
//  DictationEngine.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import Observation

/// Orchestrator dla całego flow dyktowania.
///
/// Sekwencja `startDictation()` → `stopDictation()`:
/// 1. **start**: Audio start (AVAudioEngine), pokaż FloatingDictationWindow, phase = .recording
/// 2. **stop**: Audio stop → uzyskaj WAV URL → phase = .processingWhisper
/// 3. WhisperService.transcribe(WAV) → raw text → VocabularyProcessor → phase = .pasting
/// 4. PasteService.paste(text) → cleanup WAV → phase = .completed → auto-fade window
///
/// Error handling: każda faza może rzucić błąd → phase = .error(message), window pokazuje !.
@MainActor
@Observable
final class DictationEngine {

    // MARK: - Dependencies

    let audioRecorder: AudioRecorder  // internal access dla UI (live waveform)
    let whisperService: WhisperService  // internal access dla AppCoordinator preload
    private let pasteService: PasteService
    private let floatingWindow: FloatingDictationWindow

    // MARK: - State

    /// Czy aktualnie trwa dyktowanie (recording lub processing).
    var isDictating: Bool {
        switch AppCoordinator.shared.phase {
        case .recording, .processingWhisper, .pasting:
            return true
        default:
            return false
        }
    }

    /// Aktualny audio level (re-eksport z AudioRecorder dla UI).
    var audioLevel: Float {
        audioRecorder.currentLevel
    }

    private var currentRecordingURL: URL?

    // MARK: - Init

    init(
        audioRecorder: AudioRecorder = AudioRecorder(),
        whisperService: WhisperService = WhisperService(),
        pasteService: PasteService = PasteService(),
        floatingWindow: FloatingDictationWindow = FloatingDictationWindow()
    ) {
        self.audioRecorder = audioRecorder
        self.whisperService = whisperService
        self.pasteService = pasteService
        self.floatingWindow = floatingWindow

        // Auto-stop gdy max recording duration reached
        self.audioRecorder.onMaxDurationReached = { [weak self] in
            Log.dictation.warning("Max duration reached - auto-stopping")
            Task { @MainActor [weak self] in
                await self?.stopDictation()
            }
        }
    }

    // MARK: - Public API

    /// Toggle dyktowania - jeśli idle: start, jeśli recording: stop.
    func toggle() async {
        if isDictating {
            await stopDictation()
        } else {
            await startDictation()
        }
    }

    /// Preload modelu Whisper w tle (wywołane przez AppCoordinator przy starcie aplikacji).
    /// Dzięki temu pierwszy tap Left Option = instant recording, model gotowy do transcribe.
    func preloadModel() async {
        guard whisperService.loadedModel == nil, !whisperService.isLoading else {
            return
        }
        Log.dictation.info("Preloading Whisper model in background")
        do {
            try await whisperService.loadModel(.default)
            Log.dictation.info("Model preload complete - ready for instant dictation")
        } catch {
            Log.dictation.warning("""
                Background preload failed (will retry on first dictation): \
                \(error.localizedDescription, privacy: .public)
                """)
        }
    }

    /// Rozpoczyna dyktowanie - **instant**, bez czekania na model load.
    /// Wymaga że model JEST gotowy (preloaded przy starcie aplikacji).
    /// Jeśli model nie gotowy (np. wciąż się pobiera) - hotkey jest ignorowany.
    func startDictation() async {
        guard !isDictating else {
            Log.dictation.warning("startDictation called but already dictating")
            return
        }

        // Jeśli model nie załadowany i preload nie startuje - triggeruj load TERAZ.
        // Lazy fallback: tap rozpoczyna nagrywanie + równolegle ładuje model.
        if whisperService.loadedModel == nil && !whisperService.isLoading {
            Log.dictation.info("Model not preloaded - starting background load")
            Task.detached(priority: .userInitiated) { [weak self] in
                try? await self?.whisperService.loadModel(.default)
            }
        }
        // Jeśli model się ładuje - nadal pozwól nagrywać (transcribe poczeka po stop)

        Log.dictation.info("Starting dictation (instant - mów teraz)")

        // Sprawdź uprawnienie mikrofon (must be authorized)
        guard PermissionsHelper.microphoneStatus == .authorized else {
            Log.dictation.error("Microphone not authorized - cannot start")
            await setError("Brak uprawnienia mikrofonu")
            return
        }

        // Start recording IMMEDIATELY - model już gotowy
        do {
            let url = try audioRecorder.startRecording()
            currentRecordingURL = url
            AppCoordinator.shared.phase = .recording(startedAt: Date())
            floatingWindow.show()
            SoundService.playStart()
        } catch {
            Log.dictation.error("Failed to start audio recording: \(error.localizedDescription, privacy: .public)")
            await setError(error.localizedDescription)
        }
    }

    /// Kończy dyktowanie i odpala pipeline (Whisper → paste).
    func stopDictation() async {
        guard isDictating else {
            Log.dictation.warning("stopDictation called but not dictating")
            return
        }

        Log.dictation.info("Stopping dictation - starting pipeline")

        // Stop recording, get WAV URL
        let maxRMS = audioRecorder.maxRawRMS  // capture przed stopRecording (które czyści state)
        guard let url = audioRecorder.stopRecording() else {
            Log.dictation.error("No recording URL - dictation aborted")
            await setError("Nagrywanie nie zostało rozpoczęte poprawnie")
            await dismissFloatingWindow(after: 1.5)
            return
        }
        currentRecordingURL = url

        // EARLY EXIT - cisza. Whisper trenowany na YouTube wstawia halucynacje
        // ("Dzięki za oglądanie", "Subskrybujcie") gdy dostaje cichy/pusty audio.
        // Nie wywołujemy go w ogóle - cisza = nic się nie wkleja.
        // Próg 0.01 = bardzo cicho (typowa mowa to 0.05+, szept ~0.02).
        if maxRMS < 0.01 {
            Log.dictation.info("Silent recording detected (maxRMS=\(maxRMS, privacy: .public)) - skipping transcribe")
            AppCoordinator.shared.phase = .completed(transcriptLength: 0)
            audioRecorder.cleanupRecording(at: url)
            await dismissFloatingWindow(after: 0.3)
            return
        }

        // Jeśli model nadal się ładuje (lazy load z startDictation) - czekaj
        if whisperService.loadedModel == nil {
            Log.dictation.info("Model not ready yet - waiting for load")
            AppCoordinator.shared.phase = .loadingModel
            do {
                try await whisperService.loadModel(.default)
            } catch {
                Log.dictation.error("Model load failed during stop: \(error.localizedDescription, privacy: .public)")
                await setError("Nie można załadować modelu Whisper. Sprawdź internet i spróbuj ponownie.")
                await dismissFloatingWindow(after: 4.0)
                return
            }
        }

        AppCoordinator.shared.phase = .processingWhisper

        // Pipeline:
        // 1. Whisper transcribe (z initialPrompt z Custom Words)
        // 2. VocabularyProcessor.applyFindReplace
        // 3. PasteService.paste
        do {
            // 1. Whisper z Custom Words injection
            let initialPrompt = VocabularyProcessor.generateInitialPrompt()
            let rawTranscript = try await whisperService.transcribe(
                audioFileURL: url,
                initialPrompt: initialPrompt
            )

            guard !rawTranscript.isEmpty else {
                Log.dictation.warning("Empty transcription - skipping paste")
                AppCoordinator.shared.phase = .completed(transcriptLength: 0)
                await dismissFloatingWindow(after: 0.5)
                audioRecorder.cleanupRecording(at: url)
                return
            }

            Log.dictation.info("Whisper raw: \(rawTranscript.count, privacy: .public) chars")

            // 2. Find & Replace
            let processedText = VocabularyProcessor.applyFindReplace(rawTranscript)

            // 3. Paste
            AppCoordinator.shared.phase = .pasting

            do {
                try pasteService.paste(processedText)
                AppCoordinator.shared.phase = .completed(transcriptLength: processedText.count)
                SoundService.playFinish()
            } catch let pasteError as PasteService.PasteError {
                // Special case: jeśli accessibility nie granted, tekst i tak jest w schowku
                if case .accessibilityNotGranted = pasteError {
                    Log.dictation.warning("Auto-paste blocked - text in clipboard, user must paste manually")
                    AppCoordinator.shared.phase = .completed(transcriptLength: processedText.count)
                    SoundService.playFinish()  // tekst w schowku, też success
                } else {
                    throw pasteError
                }
            }

            // Cleanup tylko po success paste (lub clipboard fallback)
            audioRecorder.cleanupRecording(at: url)

            await dismissFloatingWindow(after: 0.8)

        } catch {
            Log.dictation.error("Pipeline failed: \(error.localizedDescription, privacy: .public)")
            await setError(error.localizedDescription)
            await dismissFloatingWindow(after: 4.0)
            // NIE kasujemy WAV przy błędzie - może być potrzebny do retry
        }
    }

    // MARK: - Private helpers

    private func setError(_ message: String) async {
        AppCoordinator.shared.phase = .error(message: message)
        SoundService.playError()
        Log.dictation.error("Error shown to user: \(message, privacy: .public)")
    }

    private func dismissFloatingWindow(after delay: TimeInterval) async {
        try? await Task.sleep(for: .seconds(delay))
        floatingWindow.hide()
        // Reset phase to idle po fade out
        try? await Task.sleep(for: .milliseconds(250))
        AppCoordinator.shared.phase = .idle
    }
}
