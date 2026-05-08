// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Text.Json.Serialization;

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Konfiguracja aplikacji. Persystowane jako JSON w
/// <c>%LOCALAPPDATA%\PolskiWhisper\settings.json</c>.
/// </summary>
public sealed class AppSettings
{
    /// <summary>Klucz domyślnego modelu Whisper (z <see cref="WhisperModelInfo.All"/>).</summary>
    public string SelectedWhisperModelId { get; set; } = WhisperModelInfo.Default.Identifier;

    /// <summary>Wybrany hotkey (Win32 Virtual Key Code, np. <c>VK_RCONTROL = 0xA3</c>).</summary>
    public int HotkeyVirtualKeyCode { get; set; } = 0xA3; // Right Ctrl

    /// <summary>Tryb hotkey: <c>Toggle</c> = krótki tap włącza/wyłącza, <c>Hold</c> = push-to-talk.</summary>
    public HotkeyMode HotkeyMode { get; set; } = HotkeyMode.Toggle;

    /// <summary>Dźwięk grany przy starcie nagrywania.</summary>
    public SoundChoice StartSound { get; set; } = SoundChoice.Pop;

    /// <summary>Dźwięk grany po zakończonym wklejeniu.</summary>
    public SoundChoice FinishSound { get; set; } = SoundChoice.Tink;

    /// <summary>Maksymalna długość pojedynczego nagrania (sekundy). Domyślnie 5 min.</summary>
    public int MaxRecordingSeconds { get; set; } = 300;

    /// <summary>Czy aplikacja startuje przy logowaniu Windows (Run registry key).</summary>
    public bool LaunchAtLogin { get; set; } = false;

    /// <summary>Czy automatyczne aktualizacje są włączone (jeden klik install + restart).</summary>
    public bool AutomaticUpdatesEnabled { get; set; } = true;

    /// <summary>Czy onboarding został przejdzony (UI pokazuje wizard tylko gdy false).</summary>
    public bool OnboardingCompleted { get; set; } = false;

    /// <summary>Timestamp ostatniego sprawdzenia aktualizacji (do throttling 24h).</summary>
    public DateTimeOffset? LastUpdateCheck { get; set; }

    /// <summary>Wybór mikrofonu - identyfikator urządzenia z NAudio. <c>null</c> = default.</summary>
    public string? SelectedMicrophoneId { get; set; }

    /// <summary>Włącz GPU (DirectML) acceleration jeśli dostępne. Fallback na CPU.</summary>
    public bool UseGpuAcceleration { get; set; } = true;

    /// <summary>
    /// Język interfejsu - obecnie tylko polski. Pole na przyszłość (i18n).
    /// </summary>
    [JsonIgnore]
    public string UiLanguage => "pl-PL";

    /// <summary>
    /// Język rozpoznawania mowy w Whisper. Wymuszony "pl" w v0.1.0 - inne języki w przyszłości.
    /// </summary>
    [JsonIgnore]
    public string WhisperLanguage => "pl";

    /// <summary>
    /// Klonuje obiekt - przydatne w UI gdy chcemy mutować bez wpływu na aktualne settings.
    /// </summary>
    public AppSettings Clone() => new()
    {
        SelectedWhisperModelId = SelectedWhisperModelId,
        HotkeyVirtualKeyCode = HotkeyVirtualKeyCode,
        HotkeyMode = HotkeyMode,
        StartSound = StartSound,
        FinishSound = FinishSound,
        MaxRecordingSeconds = MaxRecordingSeconds,
        LaunchAtLogin = LaunchAtLogin,
        AutomaticUpdatesEnabled = AutomaticUpdatesEnabled,
        OnboardingCompleted = OnboardingCompleted,
        LastUpdateCheck = LastUpdateCheck,
        SelectedMicrophoneId = SelectedMicrophoneId,
        UseGpuAcceleration = UseGpuAcceleration
    };
}

/// <summary>
/// Tryb działania hotkey aplikacji.
/// </summary>
public enum HotkeyMode
{
    /// <summary>Krótki tap włącza nagrywanie, kolejny tap wyłącza.</summary>
    Toggle,

    /// <summary>Trzymaj klawisz aby nagrywać, puść aby zakończyć (push-to-talk).</summary>
    Hold
}
