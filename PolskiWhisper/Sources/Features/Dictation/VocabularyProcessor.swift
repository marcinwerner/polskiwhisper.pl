//
//  VocabularyProcessor.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation

/// Operacje na transkrypcji bazujące na słowniku użytkownika (`VocabularyStore`).
///
/// Dwie operacje:
/// 1. `generateInitialPrompt()` - łączy Custom Words w string dla Whisper `initialPrompt`
/// 2. `applyFindReplace()` - aplikuje sekwencyjnie reguły zamiany do tekstu
///
/// **Bezstanowy** - czyta z `VocabularyStore.shared` przy każdej operacji.
@MainActor
enum VocabularyProcessor {

    // MARK: - Whisper initial prompt

    /// Łączy Custom Words w string dla Whisper `initialPrompt`.
    ///
    /// Ważne: Whisper ma limit 224 tokenów dla initial prompt, więc truncate jeśli za długie.
    /// Format: zwykła lista słów oddzielonych przecinkami (Whisper traktuje to jako kontekst).
    ///
    /// - Returns: string lub nil jeśli brak Custom Words
    static func generateInitialPrompt() -> String? {
        let words = VocabularyStore.shared.customWords.map { $0.word }
        guard !words.isEmpty else { return nil }

        // Łączenie + truncate do bezpiecznej długości (~200 tokenów = ~800 znaków łacińskich,
        // dla polskiego z diakrytami niżej, ~600-700 znaków)
        let joined = words.joined(separator: ", ")
        let maxChars = 600
        if joined.count <= maxChars {
            return joined
        }

        // Truncate od końca, żeby zachować początek listy (alfabetyczna kolejność, więc rozsądny cut)
        let truncated = String(joined.prefix(maxChars))
        // Cut przy ostatnim przecinku żeby nie ucinać słowa w połowie
        if let lastComma = truncated.lastIndex(of: ",") {
            return String(truncated[..<lastComma])
        }
        return truncated
    }

    // MARK: - Find & Replace

    /// Aplikuje wszystkie Find & Replace rules sekwencyjnie do tekstu.
    ///
    /// Każda reguła może być text-based lub regex (per-rule toggle).
    /// Reguły są aplikowane w kolejności `orderIndex` (wcześniej dodane → wcześniej zaaplikowane).
    static func applyFindReplace(_ text: String) -> String {
        var result = text
        var appliedCount = 0

        for rule in VocabularyStore.shared.findReplaceRules {
            let before = result
            if rule.isRegex {
                result = applyRegex(rule, to: result)
            } else {
                result = applyText(rule, to: result)
            }
            if before != result {
                appliedCount += 1
            }
        }

        if appliedCount > 0 {
            Log.vocabulary.info("Applied \(appliedCount, privacy: .public) find&replace rules")
        }
        return result
    }

    private static func applyText(_ rule: VocabularyStore.FindReplaceRule, to text: String) -> String {
        let options: String.CompareOptions = rule.caseSensitive ? [] : [.caseInsensitive]
        return text.replacingOccurrences(
            of: rule.findText,
            with: rule.replaceWith,
            options: options
        )
    }

    private static func applyRegex(_ rule: VocabularyStore.FindReplaceRule, to text: String) -> String {
        var options: NSRegularExpression.Options = []
        if !rule.caseSensitive {
            options.insert(.caseInsensitive)
        }

        do {
            let regex = try NSRegularExpression(pattern: rule.findText, options: options)
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: rule.replaceWith
            )
        } catch {
            // NIE loguj treści regex - może zawierać prywatne dane usera
            Log.vocabulary.error("""
                Invalid regex in find&replace rule (id=\(rule.id ?? -1, privacy: .public)) \
                error: \(error.localizedDescription, privacy: .public)
                """)
            return text  // skip broken rule
        }
    }

}
