//
//  WhisperHallucinationFilter.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation

/// Filtruje znane halucynacje Whispera - frazy które model wstawia gdy dostaje
/// cichy lub niewyraźny audio (trenowany na YouTube subtitles z outros).
///
/// Strategia:
/// 1. Jeśli **cała** transkrypcja matchuje halucynację → zwróć pusty string
/// 2. Jeśli halucynacja jest **fragmentem** (na początku/końcu) → usuń ten fragment
/// 3. Inne pozostawiamy (mogą być legitne wystąpienia w środku zdania)
@MainActor
enum WhisperHallucinationFilter {

    /// Lista typowych halucynacji Whispera w języku polskim i angielskim.
    /// Case-insensitive matching.
    private static let knownHallucinations: [String] = [
        // Polish YouTube outros
        "Dzięki za oglądanie",
        "Dziękuję za oglądanie",
        "Dzięki za uwagę",
        "Dziękuję za uwagę",
        "Subskrybujcie",
        "Lubcie i subskrybujcie",
        "Subskrybujcie kanał",
        "Wszystkie prawa zastrzeżone",
        "Do zobaczenia",
        "Do zobaczenia w następnym odcinku",
        "Do następnego",
        "Trzymajcie się",
        "Pa pa",
        "Napisy stworzone przez społeczność Amara.org",
        "Napisy stworzone przez",
        "Tłumaczenie:",
        "Korekta:",

        // English (czasem leci nawet z polish lang setting)
        "Thanks for watching",
        "Thank you for watching",
        "Thanks for watching!",
        "Subscribe to my channel",
        "Don't forget to subscribe",
        "Like and subscribe",
        "See you next time",
        "Bye bye",
        "All rights reserved",
        "Subtitles by the Amara.org community",

        // Bardzo krótkie (~ pojedyncze słowa-halucynacje)
        "you",
        "Bye",
        "Thanks"
    ]

    /// Filtruje halucynacje z transkrypcji.
    static func filter(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 1. Cała transkrypcja matchuje halucynację? → wyrzuć całość
        for hallucination in knownHallucinations {
            if textEqualsIgnoringPunctuation(trimmed, hallucination) {
                return ""
            }
        }

        // 2. Sprawdź czy transkrypcja składa się WYŁĄCZNIE z halucynacji
        // (kilka połączonych typu "Dzięki za oglądanie. Subskrybujcie!")
        if isOnlyHallucinations(trimmed) {
            return ""
        }

        // 3. Usuń halucynacje na końcu zdania (zachowaj resztę)
        var result = trimmed
        for hallucination in knownHallucinations {
            // Match at end z opcjonalnymi znakami końcowymi
            let escaped = NSRegularExpression.escapedPattern(for: hallucination)
            let pattern = "\\s*\\.?\\s*\(escaped)\\s*[!.?]*\\s*$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return result
    }

    // MARK: - Private helpers

    /// Strip polskich znaków diakrytycznych. Standard `.stripDiacritics` zhandle
    /// ą→a, ę→e, ć→c, ń→n, ó→o, ś→s, ź→z, ż→z, ALE NIE ł→l (bo `ł` to osobny
    /// Unicode glyph U+0142, nie litera+diakrytyk). Dlatego manual replacement.
    private static func foldPolish(_ text: String) -> String {
        let stripped = text.applyingTransform(.stripDiacritics, reverse: false) ?? text
        return stripped
            .replacingOccurrences(of: "ł", with: "l")
            .replacingOccurrences(of: "Ł", with: "L")
    }

    /// Porównuje dwa stringi ignorując punktuację, case, whitespace **i polskie ogonki**.
    /// Diacritic-fold łapie warianty typu "Dziekuje za ogladanie" gdy Whisper zgubi polskie znaki.
    private static func textEqualsIgnoringPunctuation(_ a: String, _ b: String) -> Bool {
        let cleaned: (String) -> String = { text in
            foldPolish(text.lowercased())
                .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "  ", with: " ")
        }
        return cleaned(a) == cleaned(b)
    }

    /// Sprawdza czy text składa się WYŁĄCZNIE z halucynacji (np. "Dzięki za oglądanie. Bye bye.").
    /// Algorytm: po usunięciu wszystkich halucynacji nie zostaje nic znaczącego.
    /// Strip diacritics + ł przed porównaniem - łapie warianty bez polskich znaków.
    private static func isOnlyHallucinations(_ text: String) -> Bool {
        var stripped = foldPolish(text.lowercased())
        for hallucination in knownHallucinations {
            let folded = foldPolish(hallucination.lowercased())
            stripped = stripped.replacingOccurrences(of: folded, with: "")
        }
        // Po usunięciu zostały tylko białe znaki + punktuacja?
        let alphanumericLeft = stripped.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .count
        return alphanumericLeft < 3  // mniej niż 3 znaków = praktycznie nic
    }
}
