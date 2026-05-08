// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Rotujące komunikaty wyświetlane podczas ładowania modelu Whisper.
/// Mapping 1:1 do macOS <c>LoadingMessages</c>. Tipy zmieniają się co 5 sekund.
/// </summary>
public static class LoadingMessages
{
    /// <summary>
    /// Lista tipów rotowanych w czasie ładowania modelu (interval 5s).
    /// Przyjazne, edukacyjne - user uczy się aplikacji czekając.
    /// </summary>
    public static IReadOnlyList<string> Tips { get; } =
    [
        "Pierwsze ładowanie modelu trwa dłużej - kolejne uruchomienia są szybsze.",
        "Model trafia do pamięci RAM. Pozostanie tam aż wyłączysz aplikację.",
        "Możesz zmienić model w Ustawieniach → Whisper.",
        "Dyktowanie działa najlepiej w cichym otoczeniu, blisko mikrofonu.",
        "Po zakończeniu nagrania tekst pojawi się w aktywnym oknie automatycznie.",
        "Jeśli Whisper przekręci jakieś słowo - dodaj regułę w słowniku.",
        "Prawy Ctrl to domyślny skrót, możesz go zmienić w ustawieniach.",
        "Naciśnij Esc aby anulować nagrywanie bez wklejania.",
        "Model rozumie polskie znaki diakrytyczne - mów naturalnie.",
        "Możesz mówić długimi zdaniami - Whisper poradzi sobie z całym akapitem.",
        "Po kropce, wykrzykniku lub pytajniku aplikacja sama doda spację.",
    ];

    /// <summary>
    /// Zwraca tip dla danego indeksu (modulo długość listy).
    /// </summary>
    public static string GetTip(int index)
    {
        if (Tips.Count == 0) return string.Empty;
        var safeIndex = ((index % Tips.Count) + Tips.Count) % Tips.Count;
        return Tips[safeIndex];
    }
}
