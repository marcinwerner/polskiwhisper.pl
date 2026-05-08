// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Globalization;

namespace PolskiWhisperWin.Core.Utilities;

/// <summary>
/// Lekka implementacja SemVer dla porównywania wersji aplikacji
/// (np. <c>"0.1.0"</c> vs <c>"0.2.0"</c>). Toleruje prefix <c>"v"</c>.
/// </summary>
public readonly record struct SemanticVersion(int Major, int Minor, int Patch) : IComparable<SemanticVersion>
{
    /// <summary>Wersja "0.0.0" - placeholder.</summary>
    public static SemanticVersion Zero => new(0, 0, 0);

    /// <summary>
    /// Próbuje sparsować string typu "0.1.5", "v0.1.5", "0.1.5-beta".
    /// Pre-release suffix jest ignorowany - traktujemy tylko Major.Minor.Patch.
    /// </summary>
    public static bool TryParse(string? input, out SemanticVersion version)
    {
        version = Zero;
        if (string.IsNullOrWhiteSpace(input)) return false;

        var trimmed = input.Trim().TrimStart('v', 'V');

        // Odetnij pre-release/build metadata (po `-` lub `+`)
        var dashIdx = trimmed.IndexOfAny(['-', '+']);
        if (dashIdx >= 0) trimmed = trimmed[..dashIdx];

        var parts = trimmed.Split('.');
        if (parts.Length < 1) return false;

        int major = 0, minor = 0, patch = 0;

        if (!int.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out major))
            return false;

        if (parts.Length >= 2 &&
            !int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out minor))
            return false;

        if (parts.Length >= 3 &&
            !int.TryParse(parts[2], NumberStyles.Integer, CultureInfo.InvariantCulture, out patch))
            return false;

        version = new SemanticVersion(major, minor, patch);
        return true;
    }

    /// <summary>
    /// Parsuje string lub rzuca <see cref="FormatException"/>. Użyteczne w testach.
    /// </summary>
    public static SemanticVersion Parse(string input)
    {
        if (!TryParse(input, out var version))
            throw new FormatException($"Nieprawidłowy format wersji: '{input}'.");
        return version;
    }

    public int CompareTo(SemanticVersion other)
    {
        var majorCmp = Major.CompareTo(other.Major);
        if (majorCmp != 0) return majorCmp;

        var minorCmp = Minor.CompareTo(other.Minor);
        if (minorCmp != 0) return minorCmp;

        return Patch.CompareTo(other.Patch);
    }

    public static bool operator <(SemanticVersion a, SemanticVersion b) => a.CompareTo(b) < 0;
    public static bool operator >(SemanticVersion a, SemanticVersion b) => a.CompareTo(b) > 0;
    public static bool operator <=(SemanticVersion a, SemanticVersion b) => a.CompareTo(b) <= 0;
    public static bool operator >=(SemanticVersion a, SemanticVersion b) => a.CompareTo(b) >= 0;

    public override string ToString() => $"{Major}.{Minor}.{Patch}";
}
