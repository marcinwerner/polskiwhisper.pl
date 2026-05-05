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
/// 3. WhisperService.transcribe(WAV) → raw text → phase = .pasting
/// 4. PasteService.paste(text) → cleanup WAV → phase = .completed → auto-fade window
///
/// W Etap 2 dodajemy między 3 a 4: VocabularyProcessor + opcjonalnie OllamaService.
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
    let ollamaService: OllamaService  // internal access dla Settings UI (Etap 3)

    // MARK: - State

    /// Czy aktualnie trwa dyktowanie (recording lub processing).
    var isDictating: Bool {
        switch AppCoordinator.shared.phase {
        case .recording, .processingWhisper, .processingLLM, .pasting:
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
        floatingWindow: FloatingDictationWindow = FloatingDictationWindow(),
        ollamaService: OllamaService = OllamaService()
    ) {
        self.audioRecorder = audioRecorder
        self.whisperService = whisperService
        self.pasteService = pasteService
        self.floatingWindow = floatingWindow
        self.ollamaService = ollamaService

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
        guard let url = audioRecorder.stopRecording() else {
            Log.dictation.error("No recording URL - dictation aborted")
            await setError("Nagrywanie nie zostało rozpoczęte poprawnie")
            await dismissFloatingWindow(after: 1.5)
            return
        }
        currentRecordingURL = url

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
        // 3. (opcjonalnie) OllamaService.cleanup z anti-prompt-injection wrapper
        // 4. PasteService.paste
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
            var processedText = VocabularyProcessor.applyFindReplace(rawTranscript)

            // 3. (Optional) LLM post-processing - tylko jeśli włączone w Settings
            if AppCoordinator.shared.llmEnabled {
                processedText = await applyLLMPostProcessing(text: processedText)
            }

            // 4. Paste
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

    /// LLM post-processing przez Ollama. Jeśli Ollama nie running lub model fail -
    /// fallback do tekstu z poprzedniego kroku (graceful degradation).
    private func applyLLMPostProcessing(text: String) async -> String {
        AppCoordinator.shared.phase = .processingLLM
        Log.dictation.info("Starting LLM post-processing")

        // Health check - jeśli Ollama nie running, zwróć tekst bez cleanup
        let isHealthy = await ollamaService.healthCheck()
        guard isHealthy else {
            Log.dictation.warning("Ollama not running - skipping LLM post-processing")
            return text
        }

        let model = AppCoordinator.shared.selectedLLMModel

        // Sprawdź czy model jest zainstalowany
        guard ollamaService.isModelInstalled(model) else {
            Log.dictation.warning("""
                LLM model '\(model, privacy: .public)' not installed - skipping post-processing. \
                Install: ollama pull \(model, privacy: .public)
                """)
            return text
        }

        let systemPrompt = LLMPrompt.buildSystemPrompt(
            customTemplate: AppCoordinator.shared.customLLMSystemPrompt.isEmpty
                ? nil : AppCoordinator.shared.customLLMSystemPrompt
        )
        let userPrompt = LLMPrompt.wrapTranscript(text)

        do {
            let cleaned = try await ollamaService.generate(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                temperature: 0.0
            )
            Log.dictation.info("LLM cleanup: \(text.count, privacy: .public) -> \(cleaned.count, privacy: .public) chars")
            return cleaned
        } catch {
            Log.dictation.warning("""
                LLM cleanup failed (\(error.localizedDescription, privacy: .public)) - \
                falling back to raw transcript
                """)
            return text
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
