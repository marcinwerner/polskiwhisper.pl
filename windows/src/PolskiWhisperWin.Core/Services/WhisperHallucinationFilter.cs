// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Globalization;
using System.Text;
using Microsoft.Extensions.Logging;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Filtruje typowe halucynacje Whisper przy ciszy lub szumie tła.
/// Mapping 1:1 do macOS <c>WhisperHallucinationFilter</c> (v0.1.1+).
/// </summary>
/// <remarks>
/// Whisper często zwraca "Dziękuję za oglądanie", "Napisy stworzone przez społeczność Amara.org"
/// i podobne fragmenty napisów Youtube przy bardzo cichym audio. Filter łapie:
/// 1) Dokładne dopasowanie znanych fraz
/// 2) Diacritic-fold porównanie (łapie warianty bez polskich znaków)
/// 3) Bardzo krótkie wyniki (1-2 znaki) - prawdopodobnie noise
/// </remarks>
public sealed class WhisperHallucinationFilter
{
    private readonly ILogger<WhisperHallucinationFilter> _logger;

    /// <summary>
    /// Znane frazy halucynowane przez Whisper przy ciszy. Wszystkie w lowercase
    /// + diacritic-folded (bez polskich znaków) dla case-insensitive matching.
    /// </summary>
    private static readonly IReadOnlySet<string> KnownHallucinations = new HashSet<string>(StringComparer.Ordinal)
    {
        // Polskie napisy YouTube hallucinations
        "dziekuje za ogladanie",
        "dziekuje za uwage",
        "dziekuje za obejrzenie filmu",
        "napisy stworzone przez spolecznosc amara.org",
        "napisy: amara.org",
        "amara.org",
        "subskrybuj kanal",
        "lajkuj i subskrybuj",
        "do zobaczenia w nastepnym filmie",
        "do zobaczenia",
        // English/multilingual hallucinations
        "thanks for watching",
        "thank you for watching",
        "thank you",
        "subscribe",
        "like and subscribe",
        ".",
        "...",
        "you",
        "[music]",
        "[muzyka]",
        "(muzyka)",
        "(music)",
    };

    public WhisperHallucinationFilter(ILogger<WhisperHallucinationFilter> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Sprawdza czy <paramref name="text"/> wygląda na halucynację.
    /// Zwraca <c>true</c> jeśli tekst powinien zostać odrzucony (NIE wklejać).
    /// </summary>
    public bool IsLikelyHallucination(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return true;

        var trimmed = text.Trim();

        // Bardzo krótki wynik (1-2 znaki) - prawdopodobnie noise.
        if (trimmed.Length <= 2)
        {
            _logger.LogDebug("Hallucination filter: tekst za krótki ({Length} znaków).", trimmed.Length);
            return true;
        }

        // Dokładne dopasowanie do znanych fraz (po normalizacji).
        var normalized = NormalizeForComparison(trimmed);
        if (KnownHallucinations.Contains(normalized))
        {
            _logger.LogInformation("Hallucination filter: dopasowano znaną frazę '{Phrase}'.", normalized);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Normalizuje tekst do porównania: lowercase, trim, strip polish diacritics.
    /// "Dziękuję za oglądanie" → "dziekuje za ogladanie".
    /// </summary>
    public static string NormalizeForComparison(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;

        var lowered = input.ToLowerInvariant().Trim();

        // Diacritic-fold via NFD + filter combining marks.
        var normalizedToFormD = lowered.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(normalizedToFormD.Length);
        foreach (var ch in normalizedToFormD)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category != UnicodeCategory.NonSpacingMark)
                sb.Append(ch);
        }

        // Polskie "ł" nie jest combining mark - manualne mapping.
        return sb.ToString().Normalize(NormalizationForm.FormC)
            .Replace('ł', 'l')
            .Replace('Ł', 'l');
    }
}
