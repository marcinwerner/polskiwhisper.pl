// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Aplikuje reguły <see cref="FindReplaceRule"/> do tekstu z Whisper.
/// Wszystkie reguły są aplikowane sekwencyjnie w kolejności <c>OrderIndex ASC</c>.
/// </summary>
public sealed class VocabularyProcessor
{
    private readonly ILogger<VocabularyProcessor> _logger;

    /// <summary>Limit kompilacji regexa - zapobiega ReDoS attacks na user-supplied patterns.</summary>
    private static readonly TimeSpan RegexTimeout = TimeSpan.FromMilliseconds(200);

    public VocabularyProcessor(ILogger<VocabularyProcessor> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Aplikuje wszystkie reguły z <paramref name="rules"/> do <paramref name="input"/>.
    /// Reguły niepoprawne (zły regex) są pomijane z log warning - reszta nadal działa.
    /// </summary>
    public string Apply(string input, IReadOnlyList<FindReplaceRule> rules)
    {
        if (string.IsNullOrEmpty(input)) return input;
        if (rules.Count == 0) return input;

        var result = input;

        foreach (var rule in rules)
        {
            if (!rule.IsValid) continue;

            try
            {
                result = ApplyRule(result, rule);
            }
            catch (RegexMatchTimeoutException)
            {
                _logger.LogWarning("Regex regule {RuleId} timed out (>200ms). Pomijam.", rule.Id);
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Reguła {RuleId} ma niepoprawny regex. Pomijam.", rule.Id);
            }
        }

        return result;
    }

    private static string ApplyRule(string input, FindReplaceRule rule)
    {
        if (rule.IsRegex)
        {
            var options = RegexOptions.None;
            if (!rule.CaseSensitive) options |= RegexOptions.IgnoreCase;

            var regex = new Regex(rule.FindText, options, RegexTimeout);
            return regex.Replace(input, rule.ReplaceWith);
        }

        // Plain string match.
        var comparison = rule.CaseSensitive
            ? StringComparison.Ordinal
            : StringComparison.OrdinalIgnoreCase;

        // Manual replace przy non-default comparison (string.Replace nie ma case-insensitive overload sprzed .NET 5).
        return ReplaceCaseAware(input, rule.FindText, rule.ReplaceWith, comparison);
    }

    private static string ReplaceCaseAware(string input, string oldValue, string newValue, StringComparison comparison)
    {
        if (oldValue.Length == 0) return input;

        var result = new System.Text.StringBuilder();
        int previousIndex = 0;
        int index = input.IndexOf(oldValue, comparison);

        while (index != -1)
        {
            result.Append(input, previousIndex, index - previousIndex);
            result.Append(newValue);
            previousIndex = index + oldValue.Length;
            index = input.IndexOf(oldValue, previousIndex, comparison);
        }

        result.Append(input, previousIndex, input.Length - previousIndex);
        return result.ToString();
    }
}
