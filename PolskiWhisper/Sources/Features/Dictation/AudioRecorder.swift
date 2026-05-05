//
//  AudioRecorder.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AVFoundation
import Foundation
import Observation

/// Nagrywa audio z mikrofonu, oblicza RMS dla waveform UI, zapisuje do tymczasowego WAV.
///
/// Architektura:
/// - `AVAudioEngine` z tap na input node
/// - Każdy buffer audio:
///   1. Zapisywany do WAV file (`AVAudioFile`) - dla recovery i finalnej transkrypcji
///   2. Obliczany RMS → publishable jako `level` (0.0...1.0) dla waveform
/// - Hard limit: 5 min (300 sek) - po przekroczeniu auto-stop
///
/// Używa standardowego formatu PCM Float 16 kHz mono - optymalny dla Whisper.
@MainActor
@Observable
final class AudioRecorder {

    // MARK: - Errors

    enum AudioError: LocalizedError {
        case engineSetupFailed(underlying: Error)
        case audioFileCreationFailed(underlying: Error)
        case alreadyRecording
        case notRecording
        case recordingTooLong

        var errorDescription: String? {
            switch self {
            case .engineSetupFailed(let error):
                return "Nie udało się skonfigurować silnika audio: \(error.localizedDescription)"
            case .audioFileCreationFailed(let error):
                return "Nie udało się utworzyć pliku audio: \(error.localizedDescription)"
            case .alreadyRecording:
                return "Już trwa nagrywanie."
            case .notRecording:
                return "Brak aktywnego nagrywania."
            case .recordingTooLong:
                return "Nagranie przekroczyło limit 5 minut."
            }
        }
    }

    // MARK: - Constants

    /// Default max recording duration - 5 min. Konfigurowalne przez UserDefaults
    /// (klucz `maxRecordingDurationSeconds`). 0 = bez limitu.
    static let defaultMaxRecordingDuration: TimeInterval = 300

    /// Aktualny limit z UserDefaults.
    /// - Klucz nigdy nie ustawiony → default 300s (5 min)
    /// - Klucz = 0 → bez limitu (nagrywanie do ręcznego stop)
    /// - Klucz > 0 → explicit limit w sekundach
    static var maxRecordingDuration: TimeInterval {
        if UserDefaults.standard.object(forKey: AppCoordinator.Keys.maxRecordingDuration) == nil {
            return defaultMaxRecordingDuration
        }
        return UserDefaults.standard.double(forKey: AppCoordinator.Keys.maxRecordingDuration)
    }

    /// Sample rate dla Whisper - 16 kHz jest optymalne (Whisper i tak resampluje do 16k).
    /// Zapisujemy bezpośrednio w 16kHz Int16 mono = ~6x mniej miejsca niż native 48kHz Float32.
    private static let whisperSampleRate: Double = 16000

    // MARK: - State (observable)

    /// Aktualny poziom audio (RMS, znormalizowany do 0.0...1.0). Aktualizowany ~48 razy/sek.
    /// UI waveform powinien obserwować tę wartość.
    private(set) var currentLevel: Float = 0.0

    /// Maksymalny **surowy** RMS (przed normalizacją x5) zaobserwowany podczas całego nagrania.
    /// Używany do detekcji ciszy - jeśli max przez całe nagranie był bardzo niski (< 0.01),
    /// to znaczy że user nic nie powiedział i nie ma sensu wywoływać Whispera (który przy
    /// ciszy generuje halucynacje YT outros - "Dzięki za oglądanie", "Subskrybujcie" etc.).
    private(set) var maxRawRMS: Float = 0.0

    /// Rolling window ostatnich peak amplitudes (do real-time waveform display).
    /// Buffer 1024 samples @ 48kHz ≈ 21ms per peak → 80 bars = ~1.7s historii.
    private(set) var recentPeaks: [Float] = []

    /// Maksymalna liczba peaks w rolling window.
    private static let maxRecentPeaks: Int = 80

    /// Czy nagrywanie jest aktywne.
    private(set) var isRecording: Bool = false

    /// Aktualny czas nagrywania (sekundy od startu).
    private(set) var elapsedTime: TimeInterval = 0

    // MARK: - Private state

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var audioConverter: AVAudioConverter?
    private var converterOutputFormat: AVAudioFormat?
    private var recordingStartedAt: Date?
    private var elapsedTimer: Timer?
    private var maxDurationTimer: Timer?
    private var currentRecordingURL: URL?

    // Callback gdy auto-stopped przez max duration limit
    var onMaxDurationReached: (() -> Void)?

    // MARK: - Public API

    /// Rozpoczyna nagrywanie. Zwraca URL pliku WAV gdzie zapisywane jest audio.
    ///
    /// Self-healing: jeśli `isRecording=true` (stale state z crashed previous recording),
    /// force cleanup zamiast throwing error. To była przyczyna user-facing buga
    /// "Już trwa nagrywanie" - DictationEngine już ma swoje recovery, tu defense in depth.
    @discardableResult
    func startRecording() throws -> URL {
        if isRecording {
            Log.audio.warning("startRecording called with stale isRecording=true - force cleanup")
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            elapsedTimer?.invalidate()
            elapsedTimer = nil
            maxDurationTimer?.invalidate()
            maxDurationTimer = nil
            audioFile = nil
            audioConverter = nil
            converterOutputFormat = nil
            isRecording = false
            currentLevel = 0
            recentPeaks = []
            recordingStartedAt = nil
            currentRecordingURL = nil
            // Po cleanup kontynuujemy normalny start
        }

        Log.audio.info("Starting recording")

        // Cleanup any orphaned engine state
        engine.stop()
        engine.reset()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        Log.audio.debug("""
            Input format: sampleRate=\(inputFormat.sampleRate, privacy: .public), \
            channels=\(inputFormat.channelCount, privacy: .public)
            """)

        // Ścieżka pliku WAV
        let url = try createTempWAVURL()
        currentRecordingURL = url

        // Output format dla AudioFile: 16kHz Int16 mono - optymalne dla Whisper
        // (i tak resampluje do 16kHz wewnętrznie). Daje ~6x mniej miejsca niż
        // native 48kHz Float32. Konwersja przez AVAudioConverter w processBuffer.
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.whisperSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw AudioError.engineSetupFailed(underlying: NSError(
                domain: "PolskiWhisper.AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create output format"]
            ))
        }
        converterOutputFormat = outputFormat

        // Converter: native input (np. 48kHz Float32 stereo) → 16kHz Int16 mono
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioError.engineSetupFailed(underlying: NSError(
                domain: "PolskiWhisper.AudioRecorder",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAudioConverter"]
            ))
        }
        audioConverter = converter

        // AudioFile zapisuje converted bufery (16kHz Int16)
        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: outputFormat.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
        } catch {
            Log.audio.error("Failed to create AVAudioFile: \(error.localizedDescription, privacy: .public)")
            throw AudioError.audioFileCreationFailed(underlying: error)
        }

        // Tap na input node - capture buffers
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        // Start engine
        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            Log.audio.error("Failed to start AVAudioEngine: \(error.localizedDescription, privacy: .public)")
            throw AudioError.engineSetupFailed(underlying: error)
        }

        recordingStartedAt = Date()
        isRecording = true
        elapsedTime = 0
        maxRawRMS = 0.0  // reset dla nowego nagrania

        // Timer do aktualizacji elapsedTime (UI feedback)
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let started = self.recordingStartedAt else { return }
                self.elapsedTime = Date().timeIntervalSince(started)
            }
        }

        // Timer dla hard limit (tylko jeśli > 0, czyli limit jest aktywny)
        let maxDuration = Self.maxRecordingDuration
        if maxDuration > 0 {
            maxDurationTimer = Timer.scheduledTimer(
                withTimeInterval: maxDuration,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isRecording else { return }
                    Log.audio.warning("Max recording duration reached (\(maxDuration, privacy: .public)s) - auto-stopping")
                    self.onMaxDurationReached?()
                }
            }
        } else {
            Log.audio.info("No max duration limit - recording until manual stop")
        }

        Log.audio.info("Recording started: \(url.lastPathComponent, privacy: .public)")
        return url
    }

    /// Kończy nagrywanie. Zwraca URL pliku WAV (lub nil jeśli nie nagrywaliśmy).
    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else {
            Log.audio.warning("stopRecording called but not recording")
            return nil
        }

        Log.audio.info("Stopping recording")

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        elapsedTimer?.invalidate()
        elapsedTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        audioFile = nil // close file
        audioConverter = nil
        converterOutputFormat = nil
        isRecording = false
        currentLevel = 0
        recentPeaks = []
        recordingStartedAt = nil

        let url = currentRecordingURL
        currentRecordingURL = nil

        if let url {
            Log.audio.info("Recording stopped: \(url.lastPathComponent, privacy: .public), duration: \(self.elapsedTime, privacy: .public)s")
        }

        return url
    }

    /// Usuwa plik WAV (po success paste).
    func cleanupRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            Log.audio.info("Cleaned up: \(url.lastPathComponent, privacy: .public)")
        } catch {
            Log.audio.warning("Failed to cleanup \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Crash recovery

    /// Sprawdza czy są orphan WAV files (z poprzednich crashes/kill).
    /// Returns lista URL-i które można retransribe lub usunąć.
    static func findOrphanRecordings() -> [URL] {
        guard let dir = try? cacheDirectory() else { return [] }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return urls.filter { $0.pathExtension == "wav" }
    }

    // MARK: - Private helpers

    /// Process audio buffer: oblicz RMS + peak, konwertuj do 16kHz Int16, zapisz.
    private nonisolated func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // 1. Calculate RMS i peak na ORIGINAL Float32 buffer (lepsza precyzja)
        let rawRMS = Self.calculateRawRMS(buffer: buffer)  // bez normalizacji - dla detekcji ciszy
        let rms = min(rawRMS * 5.0, 1.0)                    // znormalizowane - dla UI level
        let peak = Self.calculatePeak(buffer: buffer)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentLevel = rms
            if rawRMS > self.maxRawRMS {
                self.maxRawRMS = rawRMS
            }
            self.appendPeak(peak)
            self.convertAndWriteBuffer(buffer)
        }
    }

    @MainActor
    private func appendPeak(_ peak: Float) {
        recentPeaks.append(peak)
        if recentPeaks.count > Self.maxRecentPeaks {
            recentPeaks.removeFirst(recentPeaks.count - Self.maxRecentPeaks)
        }
    }

    /// Konwertuje buffer (native format) → 16kHz Int16 i zapisuje do AudioFile.
    @MainActor
    private func convertAndWriteBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter,
              let outputFormat = converterOutputFormat,
              let audioFile else { return }

        // Frame count w output format (sample rate ratio)
        let inputFrames = Double(buffer.frameLength)
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(inputFrames * ratio) + 100  // safety margin

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            Log.audio.error("Failed to allocate output buffer for conversion")
            return
        }

        var error: NSError?
        var bufferConsumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if bufferConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            bufferConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error {
            Log.audio.error("Conversion error: \(error.localizedDescription, privacy: .public)")
            return
        }
        if status == .error {
            Log.audio.error("Converter returned .error status")
            return
        }
        if outputBuffer.frameLength == 0 {
            return  // brak output dla tego input bufera (typowe dla resamplera)
        }

        do {
            try audioFile.write(from: outputBuffer)
        } catch {
            Log.audio.error("Failed to write converted buffer: \(error.localizedDescription, privacy: .public)")
        }
    }

    // (writeBufferToFile usunięte - zastąpione przez convertAndWriteBuffer
    //  który robi konwersję do 16kHz Int16 przed zapisem)

    /// Oblicza peak amplitude (max abs sample) z buffera, normalizuje do 0.0...1.0.
    /// Używane do real-time waveform display (każdy bar = peak w jego time slice).
    private nonisolated static func calculatePeak(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frameLength > 0, channels > 0 else { return 0 }

        var maxPeak: Float = 0
        for channel in 0..<channels {
            let samples = channelData[channel]
            for i in 0..<frameLength {
                let absSample = abs(samples[i])
                if absSample > maxPeak { maxPeak = absSample }
            }
        }

        // Speech peaks zwykle 0.05...0.5, normalizujemy z amplification
        return min(maxPeak * 3.0, 1.0)
    }

    /// Oblicza **surowy** RMS (Root Mean Square) z buffera, bez normalizacji.
    /// Speech RMS typowo 0.01...0.3, cisza < 0.005.
    /// `nonisolated` bo to pure function (nie używa instance state ani @MainActor APIs).
    private nonisolated static func calculateRawRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frameLength > 0, channels > 0 else { return 0 }

        // Avg RMS across channels
        var totalRMS: Float = 0
        for channel in 0..<channels {
            let samples = channelData[channel]
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = samples[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            totalRMS += rms
        }
        return totalRMS / Float(channels)
    }

    /// Tworzy ścieżkę dla nowego nagrania w `~/Library/Caches/PolskiWhisper/`.
    private func createTempWAVURL() throws -> URL {
        let dir = try Self.cacheDirectory()
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return dir.appendingPathComponent("recording-\(timestamp).wav")
    }

    /// Zwraca/tworzy folder cache dla recordings.
    private static func cacheDirectory() throws -> URL {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = caches.appendingPathComponent("PolskiWhisper", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
