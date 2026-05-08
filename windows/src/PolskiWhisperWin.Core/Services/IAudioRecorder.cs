// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Wynik nagrywania - ścieżka do pliku WAV + statystyki audio.
/// </summary>
/// <param name="WavFilePath">Pełna ścieżka do nagranego pliku WAV (16kHz mono PCM).</param>
/// <param name="DurationSeconds">Długość nagrania w sekundach.</param>
/// <param name="MaxRms">Maksymalna wartość RMS (0..1) zaobserwowana w trakcie nagrywania - do silent detection.</param>
public sealed record AudioRecordingResult(
    string WavFilePath,
    double DurationSeconds,
    double MaxRms
);

/// <summary>
/// Interfejs do nagrywania audio. Implementacja w głównym projekcie używa NAudio (Windows-only).
/// W Core trzymamy tylko interfejs aby DictationEngine mógł być testowalny.
/// </summary>
public interface IAudioRecorder : IDisposable
{
    /// <summary>Czy aktualnie trwa nagrywanie.</summary>
    bool IsRecording { get; }

    /// <summary>Aktualne RMS w przedziale 0..1 - aktualizowane real-time przez waveform UI.</summary>
    double CurrentRms { get; }

    /// <summary>
    /// Event emitowany gdy poziom RMS się zmienia. Subscribed by FloatingDictationWindow.WaveformView.
    /// </summary>
    event EventHandler<double>? RmsLevelChanged;

    /// <summary>Rozpocznij nagrywanie. Tworzy WAV w temp directory.</summary>
    Task StartRecordingAsync(CancellationToken cancellationToken = default);

    /// <summary>Zatrzymaj nagrywanie i zwróć wynik. Plik WAV zostaje na dysku do zewnętrznej obsługi (Whisper).</summary>
    Task<AudioRecordingResult?> StopRecordingAsync(CancellationToken cancellationToken = default);

    /// <summary>Posprzątaj plik audio (delete temp WAV po przetworzeniu).</summary>
    void CleanupRecording(string wavFilePath);

    /// <summary>
    /// Lista dostępnych mikrofonów (urządzeń input).
    /// </summary>
    IReadOnlyList<AudioDeviceInfo> GetAvailableMicrophones();
}

/// <summary>
/// Informacja o urządzeniu audio (mikrofonie).
/// </summary>
/// <param name="Id">Identyfikator wewnętrzny urządzenia (NAudio device GUID).</param>
/// <param name="DisplayName">Nazwa do pokazania w UI (np. "Microphone (Realtek Audio)").</param>
/// <param name="IsDefault">Czy to default device w systemie.</param>
public sealed record AudioDeviceInfo(
    string Id,
    string DisplayName,
    bool IsDefault
);
