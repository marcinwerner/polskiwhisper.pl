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
        case transcriptionTimeout(seconds: Int)
        case audioFileMissing(URL)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Model Whisper nie jest załadowany. Pobierz model w Ustawieniach."
            case .modelLoadFailed(let error):
                return "Nie udało się załadować modelu Whisper: \(error.localizedDescription)"
            case .transcriptionFailed(let error):
                return "Transkrypcja nie powiodła się: \(error.localizedDescription)"
            case .transcriptionTimeout(let seconds):
                return "Whisper się zaciął - transkrypcja trwała ponad \(seconds)s. Spróbuj ponownie."
            case .audioFileMissing(let url):
                return "Plik audio nie istnieje: \(url.path)"
            }
        }
    }

    /// Maksymalny czas transkrypcji - po tym timeoutie rzucamy `transcriptionTimeout`.
    /// Chroni przed decoder hell (zaobserwowane 108s dla 10s nagrania w sesji 2026-05-06).
    /// 30s = sensible cap dla typowego use case (do ~3min nagrania).
    private static let transcriptionTimeoutSeconds: Int = 30

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
    private(set) var loadPhase: LoadPhase = .idle {
        didSet {
            // Sync rotating messages co 5s w UI dla long load operacji
            LoadingMessages.shared.update(phase: loadPhase)
        }
    }

    private var whisperKit: WhisperKit?

    /// Background timer który okresowo "puka" pages modelu w RAM żeby macOS
    /// nie evictował ich do swap pod memory pressure (zaobserwowane 488s "transcription"
    /// gdzie sam Whisper był 2.4s a reszta to page-in z disk).
    private var memoryWarmingTimer: DispatchSourceTimer?

    /// Co ile sekund robić memory warming pass. 10s = agresywny tryb dla M1 16GB
    /// pod ciągłą presją RAM (zaobserwowane 2026-06-10: 30s interval pozwalał
    /// stronom modelu zostać evicted między tickami → transkrypcje 35-85s).
    private static let memoryWarmingIntervalSeconds: Int = 10

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

            // c1+c2+c3 fix dla memory pressure: po load, rozpocznij memory warming.
            // madvise(WILLNEED) + okresowe page-touching trzyma model "hot" w RAM.
            startMemoryWarming(for: model)
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
    /// - Throws: `WhisperError.transcriptionTimeout` gdy decoding > 30s (decoder hell protection)
    func transcribe(audioFileURL: URL, initialPrompt: String? = nil) async throws -> String {
        // j1 timeout: race transcribe vs 30s timeout używając CheckedContinuation.
        //
        // **Dlaczego nie withThrowingTaskGroup**: Swift `withThrowingTaskGroup` cancel'uje
        // child tasks gdy jeden rzuci, ALE czeka na ich completion przed rethrow.
        // WhisperKit `transcribe` NIE reaguje na cancel (decoder pętla nie sprawdza
        // Task.isCancelled), więc rethrow czeka aż decoder skończy = aplikacja wisi.
        //
        // **Rozwiązanie**: ChceckedContinuation + manual lock-protected race. Pierwsza
        // strona resolved (transcribe success/error LUB timeout) wygrywa. Drugi task
        // wciąż leci w tle (background decoder dokończy) ale user dostaje error po 30s.
        let timeoutSec = Self.transcriptionTimeoutSeconds

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let resolver = TimeoutResolver(continuation: continuation)

            // Task A: faktyczny transcribe (background, może wisieć w decoder hell).
            Task { @MainActor [weak self] in
                guard let self else {
                    resolver.resume(.failure(WhisperError.modelNotLoaded))
                    return
                }
                do {
                    let result = try await self.transcribeImpl(audioFileURL: audioFileURL, initialPrompt: initialPrompt)
                    resolver.resume(.success(result))
                } catch {
                    resolver.resume(.failure(error))
                }
            }

            // Task B: timeout watchdog - wygrywa gdy A wisi.
            Task {
                try? await Task.sleep(for: .seconds(timeoutSec))
                Log.whisper.error("""
                    Transcription timeout after \(timeoutSec, privacy: .public)s - returning error to user \
                    (background decoder may continue)
                    """)
                resolver.resume(.failure(WhisperError.transcriptionTimeout(seconds: timeoutSec)))
            }
        }
    }

    /// Pomocnik do "first wins" race pattern dla `withCheckedThrowingContinuation`.
    /// CheckedContinuation MUSI być wywołany dokładnie raz - klasa zapewnia tę gwarancję
    /// poprzez NSLock + flag `resolved`.
    private final class TimeoutResolver: @unchecked Sendable {
        private let lock = NSLock()
        private var resolved = false
        private let continuation: CheckedContinuation<String, Error>

        init(continuation: CheckedContinuation<String, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<String, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard !resolved else { return }
            resolved = true
            switch result {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }

    /// Implementacja transcribe BEZ timeout wrappera (wewnętrzna).
    /// Public `transcribe()` opakowuje ten call w withThrowingTaskGroup z 30s timeoutem.
    private func transcribeImpl(audioFileURL: URL, initialPrompt: String?) async throws -> String {
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
            var combinedText = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // j1: Defensive fallback dla Custom Words decoder hell.
            //
            // Patologia: Whisper z `promptTokens` (Custom Words jak "Ofertica.pl") czasem
            // hituje `firstTokenLogProbThreshold` fallback - pierwszy token transkrypcji
            // ma niski log-prob bo model "myśli" że prompt to już cała odpowiedź. Po 1-2
            // fallbackach (temperatura 0.2, 0.4) Whisper poddaje się i zwraca empty.
            //
            // Fallback: jeśli z promptTokens zwróciło empty → retry BEZ promptTokens.
            // Lepsze user experience niż zero paste (Custom Words to "boost", nie "filter").
            // Diagnoza confirmed: 2026-05-06 sesja Marcina (Custom Words "Ofertica" → empty).
            if combinedText.isEmpty, promptTokens != nil {
                Log.whisper.warning("""
                    Empty result with promptTokens (Custom Words decoder hell) - \
                    retrying WITHOUT promptTokens
                    """)

                let retryOptions = DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    language: "pl",
                    temperature: 0.0,
                    temperatureFallbackCount: 5,
                    sampleLength: 224,
                    topK: 5,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    detectLanguage: false,
                    skipSpecialTokens: true,
                    withoutTimestamps: true,
                    wordTimestamps: false,
                    promptTokens: nil,  // KEY: nil zamiast Custom Words
                    suppressBlank: true,
                    supressTokens: nil,
                    compressionRatioThreshold: 2.4,
                    logProbThreshold: -1.0,
                    firstTokenLogProbThreshold: -1.5,
                    noSpeechThreshold: 0.6
                )

                let retryResults = try await whisperKit.transcribe(
                    audioPath: audioFileURL.path,
                    decodeOptions: retryOptions
                )
                combinedText = retryResults.map(\.text).joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                Log.whisper.info("Retry without promptTokens: \(combinedText.count, privacy: .public) chars")
            }

            let duration = Date().timeIntervalSince(startTime)

            // j5: Log raw count PRZED filtrem - rozróżnia "Whisper sam zwrócił empty"
            // (combinedText.count == 0) vs "Filter wyciął wszystko" (combinedText.count > 0).
            // Diagnostyka decoder hell + Custom Words + agresywny hallucination filter.
            Log.whisper.info("""
                Whisper raw output: \(combinedText.count, privacy: .public) chars \
                (pre-filter, decoding=\(duration, privacy: .public)s)
                """)

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
        guard let path = modelDirectoryURL(for: model) else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Zwraca URL folderu w którym WhisperKit cache'uje dany model.
    /// `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-<model>/`
    static func modelDirectoryURL(for model: Model) -> URL? {
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }
        let folderName = "openai_whisper-\(model.rawValue)"
        return docs
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(folderName)
    }

    /// Oblicza rzeczywisty rozmiar zajętej przestrzeni przez model na dysku.
    /// Używa `URLResourceValues.totalFileAllocatedSize` rekursywnie.
    static func actualModelSize(for model: Model) -> Int64? {
        guard let url = modelDirectoryURL(for: model),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return directorySize(at: url)
    }

    /// Usuwa model z dysku. Zwraca `true` jeśli usunięto pomyślnie.
    @discardableResult
    static func deleteModel(_ model: Model) -> Bool {
        guard let url = modelDirectoryURL(for: model),
              FileManager.default.fileExists(atPath: url.path) else {
            Log.whisper.info("deleteModel: \(model.rawValue, privacy: .public) - nie znaleziono na dysku")
            return false
        }
        do {
            try FileManager.default.removeItem(at: url)
            Log.whisper.info("Usunięto model: \(model.rawValue, privacy: .public)")
            return true
        } catch {
            Log.whisper.error("Nie udało się usunąć modelu \(model.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Memory warming (anti memory-pressure)
    //
    // Problem: zaobserwowane 2026-05-12 - na M1 16GB pod memory pressure,
    // strony modelu Whisper Turbo (1.5 GB) były evictowane do swap. Gdy user
    // wciska hotkey, WhisperKit musi page-in 1.5 GB z disk = 8 minut "wisi"
    // mimo że sam decoding to 2-3 sek.
    //
    // Rozwiązanie: po load modelu, mmap pliki + madvise(WILLNEED) + okresowe
    // touchowanie pages żeby macOS trzymał je w "active" zamiast "inactive".
    // To NIE jest mlock (wymagałby Apple entitlements) - tylko soft hint +
    // ciągłe sygnalizowanie "te strony są w użyciu, nie evictuj".

    /// Synchroniczny pre-warming pass - wywołać PRZED transkrypcją żeby zagwarantować
    /// że model jest w aktywnym RAM (nie evicted do swap między timer ticks).
    /// Dodaje ~0.5-1.5s do pipeline ale eliminuje 30-85s spikes pod memory pressure.
    @MainActor
    func forceMemoryWarming() async {
        guard let model = loadedModel,
              let folderURL = Self.modelDirectoryURL(for: model)
        else { return }

        // Wykonaj na background queue z high priority - blokuje await ale nie main thread.
        await Task.detached(priority: .userInitiated) {
            Self.applyMemoryHints(folderURL: folderURL, initial: false)
        }.value
    }

    /// Rozpoczyna memory warming dla modelu. Anuluje poprzedni timer jeśli istnieje.
    private func startMemoryWarming(for model: Model) {
        memoryWarmingTimer?.cancel()
        memoryWarmingTimer = nil

        guard let folderURL = Self.modelDirectoryURL(for: model) else {
            Log.whisper.warning("Memory warming: brak folderURL dla \(model.rawValue, privacy: .public)")
            return
        }

        // Initial pre-warm + madvise hint - sygnał do macOS że strony będą potrzebne.
        Self.applyMemoryHints(folderURL: folderURL, initial: true)

        // Periodic page-touching co 30s żeby strony nie zostały oznaczone jako inactive.
        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue.global(qos: .background)
        )
        timer.schedule(
            deadline: .now() + .seconds(Self.memoryWarmingIntervalSeconds),
            repeating: .seconds(Self.memoryWarmingIntervalSeconds)
        )
        timer.setEventHandler { [folderURL] in
            Self.applyMemoryHints(folderURL: folderURL, initial: false)
        }
        timer.resume()
        memoryWarmingTimer = timer

        Log.whisper.info("""
            Memory warming aktywne dla \(model.rawValue, privacy: .public) - \
            tick co \(Self.memoryWarmingIntervalSeconds, privacy: .public)s
            """)
    }

    /// Iteruje pliki w folderze modelu, mmap + madvise(WILLNEED) + touch each page.
    /// `initial=true` loguje rezultaty; w periodic ticks loguje tylko jeśli >100ms (anomalia).
    /// `nonisolated` żeby móc wywołać z background queue (Task.detached, DispatchSource).
    nonisolated private static func applyMemoryHints(folderURL: URL, initial: Bool) {
        let start = Date()
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var totalBytes: Int64 = 0
        var filesTouched: Int = 0

        for case let fileURL as URL in enumerator {
            // Tylko regular files (nie symlinks/directories)
            guard let isFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isFile,
                  let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size > 0
            else {
                continue
            }

            // Tylko pliki które realnie składają się na model - skip metadata/json (<1KB).
            // Skupiamy się na .mlmodelc weights które są duże.
            guard size > 1024 else { continue }

            let fd = open(fileURL.path, O_RDONLY)
            guard fd >= 0 else { continue }
            defer { close(fd) }

            guard let ptr = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0),
                  ptr != UnsafeMutableRawPointer(bitPattern: -1)
            else {
                continue
            }
            defer { munmap(ptr, size) }

            // madvise WILLNEED: hint do kernela żeby pre-fetch te strony do RAM
            // i traktował je jako "soon to be accessed".
            madvise(ptr, size, MADV_WILLNEED)

            // madvise WILLNEED 2x dla wzmocnienia hintu (zaobserwowane: kernel czasem
            // ignoruje pojedynczy hint pod heavy memory pressure).
            madvise(ptr, size, MADV_WILLNEED)

            // Touchowanie pierwszego byte każdej strony (16 KB na Apple Silicon)
            // + sumowanie do `volatile` var żeby kompilator nie zoptymalizował reads.
            // Sum trzymamy jako side-effect żeby cały read pipeline szedł przez CPU/cache.
            let pageSize = 16384
            let typedPtr = ptr.assumingMemoryBound(to: UInt8.self)
            var sink: UInt64 = 0  // accumulator - prevent dead-code elimination
            var offset = 0
            while offset < size {
                sink &+= UInt64(typedPtr[offset])  // read = touch + accumulate
                offset += pageSize
            }
            // Trick żeby kompilator NIE wyrzucił loop - logujemy sink wartość gdy <0
            // (nigdy się nie zdarzy, ale dependency drzewo zostaje).
            if sink == .max { Log.whisper.debug("warming sink saturation impossible") }

            totalBytes += Int64(size)
            filesTouched += 1
        }

        let elapsed = Date().timeIntervalSince(start)
        if initial || elapsed > 0.1 {
            // Initial pass loguje zawsze; periodic loguje tylko jeśli wolne (anomalia = swap I/O)
            Log.whisper.info("""
                Memory warming \(initial ? "INIT" : "TICK", privacy: .public): \
                touched \(filesTouched, privacy: .public) files / \
                \(totalBytes / 1_000_000, privacy: .public) MB in \(elapsed, privacy: .public)s
                """)
        }
    }
}
