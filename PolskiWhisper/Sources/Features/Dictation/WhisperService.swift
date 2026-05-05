//
//  WhisperService.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import Observation
import WhisperKit

/// Wrapper na WhisperKit dla transkrypcji audio do tekstu.
///
/// Konfiguracja:
/// - **Język**: zawsze "pl" (wymuszone, ADR-003)
/// - **Default model**: `large-v3-turbo` (8x szybszy, ~99% jakości large-v3)
/// - **CoreML + Apple Neural Engine** (przez WhisperKit)
///
/// Lifecycle:
/// 1. `init` - utworzenie instance, NIE ładuje modelu (lazy)
/// 2. `loadModel(name:)` - pobranie/załadowanie modelu (1-3 GB, jednorazowo)
/// 3. `transcribe(audioFile:)` - transkrypcja (wielokrotnie po load)
@MainActor
@Observable
final class WhisperService {

    // MARK: - Errors

    enum WhisperError: LocalizedError {
        case modelNotLoaded
        case modelLoadFailed(underlying: Error)
        case transcriptionFailed(underlying: Error)
        case audioFileMissing(URL)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Model Whisper nie jest załadowany. Pobierz model w Ustawieniach."
            case .modelLoadFailed(let error):
                return "Nie udało się załadować modelu Whisper: \(error.localizedDescription)"
            case .transcriptionFailed(let error):
                return "Transkrypcja nie powiodła się: \(error.localizedDescription)"
            case .audioFileMissing(let url):
                return "Plik audio nie istnieje: \(url.path)"
            }
        }
    }

    // MARK: - Available models

    /// Modele Whisper które można pobrać. Default = quantized Whisper Turbo (547MB, szybki download).
    enum Model: String, CaseIterable, Identifiable {
        case tiny = "tiny"
        case base = "base"
        case small = "small"
        case medium = "medium"
        case largeV3Turbo547 = "large-v3-v20240930_547MB"
        case largeV3Turbo = "large-v3-v20240930"
        case largeV3 = "large-v3"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .tiny: return "Tiny (75 MB, słaba jakość, szybki)"
            case .base: return "Base (145 MB, mierna jakość)"
            case .small: return "Small (460 MB, dobra jakość)"
            case .medium: return "Medium (1.5 GB, bardzo dobra jakość)"
            case .largeV3Turbo547: return "Whisper Turbo 547 MB (lite - mniejszy, szybszy)"
            case .largeV3Turbo: return "Whisper Turbo 1.5 GB (rekomendowany - najlepszy polski)"
            case .largeV3: return "Large v3 3 GB (najlepsza jakość, wolny)"
            }
        }

        /// Przybliżony rozmiar modelu w bajtach - do UI progress / messaging.
        var approximateBytes: Int64 {
            switch self {
            case .tiny: return 75_000_000
            case .base: return 145_000_000
            case .small: return 460_000_000
            case .medium: return 1_500_000_000
            case .largeV3Turbo547: return 547_000_000
            case .largeV3Turbo: return 1_500_000_000
            case .largeV3: return 3_000_000_000
            }
        }

        static let `default`: Model = .largeV3Turbo
    }

    // MARK: - Load phase

    /// Faza ładowania modelu - pozwala UI rozróżnić download (z prawdziwym progressem)
    /// od load do RAM (długi, bez callback - pokazujemy spinner zamiast paska).
    enum LoadPhase: Equatable {
        case idle
        case downloading(progress: Double)  // 0.0...1.0 rzeczywisty
        case loadingToRAM                    // brak progress callback - spinner
        case ready
    }

    // MARK: - State

    private(set) var loadedModel: Model?
    private(set) var isLoading: Bool = false
    private(set) var loadProgress: Double = 0.0  // 0.0...1.0 (zachowane dla backward compat)
    private(set) var loadPhase: LoadPhase = .idle

    private var whisperKit: WhisperKit?

    // MARK: - Public API

    /// Ładuje model. Jeśli nie pobrany - pobiera z progress tracking.
    ///
    /// Two-step process:
    /// 1. Jeśli model nie jest cached → `WhisperKit.download(...)` z progressCallback (loadProgress 0...0.9)
    /// 2. Load model do RAM przez WhisperKitConfig (loadProgress 0.9 → 1.0)
    ///
    /// Race-safe: jeśli load już trwa, drugi tap czeka na zakończenie pierwszego.
    func loadModel(_ model: Model = .default) async throws {
        // Quick return jeśli już załadowany
        if loadedModel == model && whisperKit != nil {
            Log.whisper.info("Model \(model.rawValue, privacy: .public) already loaded")
            return
        }

        // Jeśli load trwa - czekaj
        if isLoading {
            Log.whisper.info("Model load already in progress - waiting")
            while isLoading {
                try await Task.sleep(for: .milliseconds(200))
            }
            if loadedModel == model && whisperKit != nil {
                return
            }
        }

        Log.whisper.info("Loading model: \(model.rawValue, privacy: .public)")
        isLoading = true
        loadProgress = 0.0
        loadPhase = .downloading(progress: 0.0)
        defer {
            isLoading = false
        }

        do {
            // Step 1: Download (jeśli nie cached) z **rzeczywistym** progress 0-100%.
            // Przed v0.1.1 progres był skalowany do 0-90% z zarezerwowaniem 90-100% dla
            // load do RAM, co dawało użytkownikowi mylne "stuck na 90%". Teraz UI
            // rozróżnia fazy: download (pasek 0-100%) vs loadingToRAM (spinner).
            var modelFolderURL: URL?
            if !Self.isModelDownloaded(model) {
                Log.whisper.info("Model not cached - downloading with progress tracking")
                modelFolderURL = try await WhisperKit.download(
                    variant: model.rawValue,
                    progressCallback: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            let frac = progress.fractionCompleted
                            self?.loadProgress = frac
                            self?.loadPhase = .downloading(progress: frac)
                        }
                    }
                )
                Log.whisper.info("Download complete, loading to RAM...")
            } else {
                Log.whisper.info("Model already cached, loading to RAM...")
            }

            // Step 2: Load do RAM - brak progress callback (WhisperKit init blocking).
            // UI pokaże indeterminate spinner z tekstem "Ładowanie do pamięci...".
            loadPhase = .loadingToRAM
            loadProgress = 1.0  // pasek pełny - spinner przejmuje rolę progress UI

            let config = WhisperKitConfig(
                model: model.rawValue,
                modelFolder: modelFolderURL?.path,
                verbose: true,
                logLevel: .info,
                prewarm: true,
                load: true,
                download: true
            )

            whisperKit = try await WhisperKit(config)
            loadedModel = model
            loadPhase = .ready

            Log.whisper.info("Model loaded successfully: \(model.rawValue, privacy: .public)")
        } catch {
            whisperKit = nil
            loadedModel = nil
            loadPhase = .idle
            Log.whisper.error("Model load failed: \(error.localizedDescription, privacy: .public)")
            throw WhisperError.modelLoadFailed(underlying: error)
        }
    }

    /// Transkrybuje plik audio do tekstu.
    ///
    /// - Parameters:
    ///   - audioFileURL: ścieżka do pliku audio (WAV, MP3, M4A - WhisperKit obsługuje większość)
    ///   - initialPrompt: opcjonalny prompt który "boostuje" konkretne słowa (Custom Words feature - Etap 2)
    /// - Returns: transkrybowany tekst (po polsku)
    func transcribe(audioFileURL: URL, initialPrompt: String? = nil) async throws -> String {
        guard let whisperKit else {
            throw WhisperError.modelNotLoaded
        }

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw WhisperError.audioFileMissing(audioFileURL)
        }

        Log.whisper.info("Transcribing: \(audioFileURL.lastPathComponent, privacy: .public)")
        let startTime = Date()

        do {
            // Initial prompt - Custom Words które boostują rozpoznawanie własnych słów.
            // WhisperKit przyjmuje go przez `promptTokens` (tokenized) lub `prefixTokens`.
            // Bezpośrednio jako prompt text przekazujemy jako tokens po tokenizacji.
            let promptTokens = await initialPromptTokens(for: initialPrompt)

            // Decoding options: wymuszamy język polski + anti-halucynacja thresholds.
            //
            // ANTY-HALUCYNACJA (Whisper trenowany na YT subtitles wstawia outro typu
            // "Dzięki za oglądanie", "Wszystkie prawa zastrzeżone" gdy audio jest
            // cichy/pusty/krótki):
            // - noSpeechThreshold: 0.6 - jeśli VAD probability "to nie mowa" > 0.6, skip segment
            // - compressionRatioThreshold: 2.4 - wykrywa repetytywne halucynacje
            // - logProbThreshold: -1.0 - odrzuca low-confidence transcriptions
            let decodingOptions = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: "pl",
                temperature: 0.0,           // deterministic output
                temperatureFallbackCount: 5,
                sampleLength: 224,          // standard Whisper context
                topK: 5,
                usePrefillPrompt: true,
                usePrefillCache: true,
                detectLanguage: false,      // wymuszamy "pl", nie auto-detect
                skipSpecialTokens: true,
                withoutTimestamps: true,    // chcemy tylko tekst
                wordTimestamps: false,
                promptTokens: promptTokens,
                suppressBlank: true,
                supressTokens: nil,
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.0,
                firstTokenLogProbThreshold: -1.5,
                noSpeechThreshold: 0.6
            )

            let results = try await whisperKit.transcribe(
                audioPath: audioFileURL.path,
                decodeOptions: decodingOptions
            )

            // Combine results (multi-segment audio może mieć kilka entries)
            let combinedText = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let duration = Date().timeIntervalSince(startTime)

            // Filter halucynacji - Whisper często generuje YT outros gdy audio jest cichy
            let filtered = WhisperHallucinationFilter.filter(combinedText)
            if filtered != combinedText {
                // Loguj tylko fakt + długości (NIE treść transkrypcji - prywatność)
                Log.whisper.warning("""
                    Filtered hallucination: \(combinedText.count, privacy: .public) chars \
                    -> \(filtered.count, privacy: .public) chars
                    """)
            }

            Log.whisper.info("""
                Transcription complete in \(duration, privacy: .public)s, \
                length=\(filtered.count, privacy: .public) chars
                """)

            return filtered
        } catch {
            Log.whisper.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            throw WhisperError.transcriptionFailed(underlying: error)
        }
    }

    /// Tokenizuje initial prompt do tokenów Whisper (z prefix `<|startofprev|>`).
    /// Używane do "boost" Custom Words w rozpoznawaniu.
    private func initialPromptTokens(for promptText: String?) async -> [Int]? {
        guard let promptText, !promptText.isEmpty,
              let whisperKit, let tokenizer = whisperKit.tokenizer else {
            return nil
        }

        // Whisper convention: prompt poprzedzony "<|startofprev|>" tokenem (50361)
        // i zakończony przed audio. WhisperKit tokenizer obsługuje to przez special tokens.
        do {
            let encoded = tokenizer.encode(text: " " + promptText)
            // Limit do 224 tokenów (Whisper max context dla initial prompt)
            let truncated = Array(encoded.suffix(224))
            return truncated
        }
    }

    /// Sprawdza czy model jest dostępny lokalnie (bez pobierania).
    static func isModelDownloaded(_ model: Model) -> Bool {
        // WhisperKit cache w ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-<model>/
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return false
        }

        // WhisperKit dodaje prefix "openai_whisper-" do model name w ścieżce repo
        let folderName = "openai_whisper-\(model.rawValue)"

        let path = docs
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(folderName)

        return FileManager.default.fileExists(atPath: path.path)
    }
}
