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
    ///
    /// Source of truth: `audioRecorder.isRecording` dla fazy recording (faktyczny stan).
    /// Phase to fallback dla post-record fazy (Whisper transcribing, paste).
    /// Wcześniej tylko phase - prowadziło do desync gdy phase rozjedzie się z audio engine
    /// (bug "Już trwa nagrywanie" zaobserwowany w produkcji).
    var isDictating: Bool {
        if audioRecorder.isRecording { return true }
        switch AppCoordinator.shared.phase {
        case .processingWhisper, .pasting:
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

    /// Auto-spacing state: ostatni paste timestamp + ostatni znak.
    /// Używane do detekcji "kontynuacji dyktowania" - gdy user nagrywa na raty,
    /// drugie dyktowanie po kropce dostaje prepend " " żeby nie było "zdanie.Drugie".
    private var lastPasteAt: Date?
    private var lastPasteEndedWithTerminator: Bool = false

    /// Próg czasowy "continuation" - po tym czasie zakładamy że user przeniósł
    /// focus do innego okna/dokumentu i auto-spacing nie ma sensu.
    private static let continuationWindow: TimeInterval = 60

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

    /// Anuluje nagrywanie - audio file kasujemy, NIC nie wkleja się, widget się zamyka.
    /// Wywoływane przez ESC podczas fazy `.recording` (NIE podczas Whisper inference).
    /// Daje user'owi natychmiastowy "abort" gdy zauważy że źle naciska / przeszkodziło coś.
    func cancelDictation() async {
        guard case .recording = AppCoordinator.shared.phase else {
            Log.dictation.warning("cancelDictation called but not in recording phase - ignoring")
            return
        }

        Log.dictation.info("Dictation cancelled by user (ESC)")

        // Stop audio + delete file (NIE process)
        if let url = audioRecorder.stopRecording() {
            audioRecorder.cleanupRecording(at: url)
        }
        currentRecordingURL = nil

        // Cichy dźwięk + dismiss widget (jak silent recording)
        AppCoordinator.shared.phase = .completed(transcriptLength: 0)
        await dismissFloatingWindow(after: 0.2)
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
        // Defensive recovery: jeśli audioRecorder ma stale isRecording=true (z poprzedniego
        // nieukończonego nagrania, np. crash w pipeline), force stop + reset stanu.
        // To naprawia bug "Już trwa nagrywanie" gdzie tap wynikał w error zamiast start.
        if audioRecorder.isRecording {
            Log.dictation.warning("Stale isRecording=true detected - force stop + reset before fresh start")
            _ = audioRecorder.stopRecording()
            AppCoordinator.shared.phase = .idle
        }

        guard !isDictating else {
            Log.dictation.warning("startDictation called but already dictating (phase=\(String(describing: AppCoordinator.shared.phase), privacy: .public))")
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

        // j2: Long-decoding indicator. Whisper Turbo zwykle ~1-2s decoding, ale
        // przy decoder hell (Custom Words + niski confidence + temperatureFallbackCount)
        // może zająć 30-90s. Po 5s zmieniamy phase żeby widget pokazał że to NIE freeze.
        // Task jest cancelled gdy transcribe zwróci wcześniej (przed 5s).
        let longTask: Task<Void, Never>? = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if case .processingWhisper = AppCoordinator.shared.phase {
                Log.dictation.info("Whisper decoding > 5s - showing long-running indicator")
                AppCoordinator.shared.processingTakingLong = true
            }
        }

        // Pipeline:
        // 1. Whisper transcribe (z initialPrompt z Custom Words)
        // 2. VocabularyProcessor.applyFindReplace (off main thread - CPU-bound)
        // 3. PasteService.paste
        //
        // **Profilowanie**: każdy krok ma Log.dictation.info ze znacznikiem
        // `pipeline-stepN` żeby zdiagnozować gdzie wisi (znaleziony 2026-05-11
        // 39s gap między Whisper complete a paste w sesji 15:15:59).
        do {
            // 1. Whisper z Custom Words injection
            let pipelineStartedAt = Date()
            Log.dictation.info("pipeline-step1: generating initialPrompt")
            let initialPrompt = VocabularyProcessor.generateInitialPrompt()
            Log.dictation.info("pipeline-step1: calling Whisper.transcribe (prompt=\(initialPrompt?.count ?? 0, privacy: .public) chars)")
            let rawTranscript = try await whisperService.transcribe(
                audioFileURL: url,
                initialPrompt: initialPrompt
            )
            let afterWhisperAt = Date()
            Log.dictation.info("pipeline-step1-done: Whisper returned \(rawTranscript.count, privacy: .public) chars in \(afterWhisperAt.timeIntervalSince(pipelineStartedAt), privacy: .public)s")

            longTask?.cancel()  // j2: Whisper się skończył - anuluj long-watcher (jeszcze nie odpalił)
            Log.dictation.info("pipeline-step2: long-watcher cancelled, checking empty")

            guard !rawTranscript.isEmpty else {
                Log.dictation.warning("Empty transcription - skipping paste")
                // j3: szybsze dismiss przy empty - nie ma co user'owi czekać
                AppCoordinator.shared.phase = .completed(transcriptLength: 0)
                await dismissFloatingWindow(after: 0.3)
                audioRecorder.cleanupRecording(at: url)
                return
            }

            Log.dictation.info("Whisper raw: \(rawTranscript.count, privacy: .public) chars")

            // 2. Find & Replace - profilowane.
            // 12 reguł literal replace na 119 chars typowo <1ms.
            // VocabularyProcessor jest @MainActor (używa @MainActor VocabularyStore),
            // więc zostaje na main thread. Logi pokażą czy to wąskie gardło.
            Log.dictation.info("pipeline-step3: applyFindReplace")
            let fnrStartedAt = Date()
            var processedText = VocabularyProcessor.applyFindReplace(rawTranscript)
            Log.dictation.info("pipeline-step3-done: F&R returned \(processedText.count, privacy: .public) chars in \(Date().timeIntervalSince(fnrStartedAt), privacy: .public)s")

            // 2.5. Auto-spacing: gdy user nagrywa na raty (zdanie kończące się .!?
            // potem druga transkrypcja), prepend " " żeby uniknąć "zdanie.Drugie".
            // Window 60s = continuation, dłużej = user pewnie zmienił focus.
            Log.dictation.info("pipeline-step4: auto-spacing check")
            if let lastTime = lastPasteAt,
               Date().timeIntervalSince(lastTime) < Self.continuationWindow,
               lastPasteEndedWithTerminator,
               let firstChar = processedText.first,
               !firstChar.isWhitespace {
                processedText = " " + processedText
                Log.dictation.info("Auto-spacing: prepended space (continuation after sentence-end)")
            }

            // 3. Paste
            Log.dictation.info("pipeline-step5: setting phase=.pasting")
            AppCoordinator.shared.phase = .pasting

            Log.dictation.info("pipeline-step6: calling pasteService.paste")
            let pasteStartedAt = Date()
            do {
                try pasteService.paste(processedText)
                Log.dictation.info("pipeline-step6-done: paste success in \(Date().timeIntervalSince(pasteStartedAt), privacy: .public)s")
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

            // Update auto-spacing state - następny paste w 60s sprawdzi czy prepend space.
            lastPasteAt = Date()
            let terminatorChars: Set<Character> = [".", "!", "?"]
            lastPasteEndedWithTerminator = processedText.last.map { terminatorChars.contains($0) } ?? false

            // Cleanup tylko po success paste (lub clipboard fallback)
            audioRecorder.cleanupRecording(at: url)

            Log.dictation.info("pipeline-complete: total=\(Date().timeIntervalSince(pipelineStartedAt), privacy: .public)s, whisper=\(afterWhisperAt.timeIntervalSince(pipelineStartedAt), privacy: .public)s, post-whisper=\(Date().timeIntervalSince(afterWhisperAt), privacy: .public)s")
            await dismissFloatingWindow(after: 0.8)

        } catch {
            longTask?.cancel()  // j2: pipeline error - anuluj long-watcher
            Log.dictation.error("Pipeline failed: \(error.localizedDescription, privacy: .public)")
            await setError(error.localizedDescription)
            // j3: krótszy delay przy błędzie - 4s było za długo, user już wie że failed
            await dismissFloatingWindow(after: 2.0)
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
        // j2: reset long-running flagi razem z phase
        AppCoordinator.shared.processingTakingLong = false
    }
}
