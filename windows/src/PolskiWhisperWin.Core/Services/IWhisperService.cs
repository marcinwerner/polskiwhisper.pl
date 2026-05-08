// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Status ładowania modelu Whisper.
/// </summary>
public enum WhisperLoadStatus
{
    /// <summary>Model jeszcze nie ładowany.</summary>
    NotLoaded,

    /// <summary>Model jest pobierany z Hugging Face (faza Download).</summary>
    Downloading,

    /// <summary>Plik jest na dysku, jest ładowany do RAM.</summary>
    LoadingToMemory,

    /// <summary>Model gotowy do transkrypcji.</summary>
    Ready,

    /// <summary>Coś poszło nie tak.</summary>
    Failed
}

/// <summary>
/// Postęp pobierania modelu - 0..1 + opcjonalny komunikat.
/// </summary>
/// <param name="Progress">Procent ukończenia 0..1.</param>
/// <param name="BytesDownloaded">Pobrane bajty.</param>
/// <param name="TotalBytes">Całkowite bajty (może być null jeśli serwer nie poda Content-Length).</param>
/// <param name="StatusMessage">Komunikat dla user (np. "Pobieram model...", "Ładuję do pamięci...").</param>
public sealed record WhisperLoadProgress(
    double Progress,
    long BytesDownloaded,
    long? TotalBytes,
    string StatusMessage
);

/// <summary>
/// Whisper transcription engine - wrapper na Whisper.net.
/// </summary>
public interface IWhisperService : IAsyncDisposable
{
    /// <summary>Aktualny status modelu.</summary>
    WhisperLoadStatus LoadStatus { get; }

    /// <summary>
    /// Załaduj model do pamięci. Jeśli plik nie istnieje, pobierze z Hugging Face.
    /// </summary>
    /// <param name="modelIdentifier">Identyfikator z <c>WhisperModelInfo.All</c>.</param>
    /// <param name="progress">Reporter postępu - update co 250ms.</param>
    /// <param name="cancellationToken">Pozwala anulować pobieranie.</param>
    Task LoadModelAsync(
        string modelIdentifier,
        IProgress<WhisperLoadProgress>? progress = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Transkrybuje WAV file do tekstu po polsku.
    /// </summary>
    /// <param name="wavFilePath">Ścieżka do nagranego WAV (16kHz mono PCM).</param>
    /// <param name="timeout">Hard timeout - przerywa jeśli Whisper przekroczy limit (typowo 30s).</param>
    /// <param name="cancellationToken">Anuluje transkrypcję.</param>
    /// <returns>Surowy tekst (bez vocabulary processing).</returns>
    Task<string> TranscribeAsync(
        string wavFilePath,
        TimeSpan timeout,
        CancellationToken cancellationToken = default);

    /// <summary>Zwolnij pamięć RAM (rozłącz model). Call przy zmianie modelu.</summary>
    Task UnloadAsync();
}
