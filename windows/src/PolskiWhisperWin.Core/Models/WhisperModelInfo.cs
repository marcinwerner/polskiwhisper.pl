// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Metadane modelu Whisper - rozmiar, jakość, ścieżka pobrania.
/// Lista <see cref="All"/> mirroruje opcje dostępne w macOS app (5 modeli).
/// </summary>
/// <param name="Identifier">Klucz wewnętrzny (np. "ggml-large-v3-turbo").</param>
/// <param name="DisplayName">Nazwa do pokazania w UI (np. "Whisper Turbo (1.5 GB) - rekomendowany").</param>
/// <param name="ApproximateSizeBytes">Rozmiar pliku ~ (do prezentacji w UI).</param>
/// <param name="DownloadUrl">URL do pliku ggml na Hugging Face.</param>
/// <param name="QualityRating">Ocena jakości polskiego (1-5 gwiazdek).</param>
/// <param name="IsDefault">Czy to domyślny model przy first install.</param>
public sealed record WhisperModelInfo(
    string Identifier,
    string DisplayName,
    long ApproximateSizeBytes,
    string DownloadUrl,
    int QualityRating,
    bool IsDefault
)
{
    /// <summary>Lista dostępnych modeli (mirror macOS WhisperKit options).</summary>
    public static IReadOnlyList<WhisperModelInfo> All { get; } =
    [
        new WhisperModelInfo(
            "ggml-tiny",
            "Tiny (75 MB) - szybki, niska jakość",
            75 * 1024L * 1024L,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
            QualityRating: 2,
            IsDefault: false),
        new WhisperModelInfo(
            "ggml-base",
            "Base (142 MB) - kompromis",
            142 * 1024L * 1024L,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
            QualityRating: 3,
            IsDefault: false),
        new WhisperModelInfo(
            "ggml-small",
            "Small (466 MB) - dobra jakość",
            466 * 1024L * 1024L,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
            QualityRating: 4,
            IsDefault: false),
        new WhisperModelInfo(
            "ggml-large-v3-turbo",
            "Whisper Turbo (1.5 GB) - rekomendowany dla polskiego",
            1_500L * 1024L * 1024L,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin",
            QualityRating: 5,
            IsDefault: true),
        new WhisperModelInfo(
            "ggml-large-v3",
            "Whisper Large v3 (3 GB) - najwyższa jakość, wolniejszy",
            3_000L * 1024L * 1024L,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin",
            QualityRating: 5,
            IsDefault: false),
    ];

    /// <summary>Domyślny model używany przy first run / reset.</summary>
    public static WhisperModelInfo Default => All.First(m => m.IsDefault);

    /// <summary>Znajdź model po identyfikatorze, fallback na default.</summary>
    public static WhisperModelInfo FindOrDefault(string? identifier) =>
        All.FirstOrDefault(m => m.Identifier == identifier) ?? Default;
}
