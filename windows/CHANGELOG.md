# Changelog - PolskiWhisper Windows

Wszystkie znaczące zmiany w wersji Windows. Format na podstawie [Keep a Changelog](https://keepachangelog.com).

## [0.1.0] - Wstępna wersja Windows (data publikacji TBD)

Pierwsza wersja PolskiWhisper na Windows - port z macOS w pełnej parze funkcji.

### Nowości

- **Dyktowanie po polsku** w dowolnej aplikacji - naciśnij prawy Ctrl, mów, naciśnij ponownie
- **System tray** - aplikacja chodzi w tle, ikona w pasku zadań
- **Onboarding (5 kroków)** - mikrofon, model Whisper, hotkey, podstawowe wskazówki
- **Floating waveform window** - widget pokazuje poziom dźwięku w czasie rzeczywistym
- **Esc anuluje** nagrywanie bez wklejania
- **Auto-spacja** po kropce, wykrzykniku, pytajniku w oknie 60 sekund (dyktowanie na raty)
- **9 dźwięków** systemowych do wyboru (osobno start i koniec nagrywania)
- **Słownik Find & Replace** z drag-and-drop reorderowaniem
- **Pre-konfigurowane modele Whisper**: Tiny, Base, Small, Whisper Turbo (1.5 GB) - rekomendowany, Large v3 (3 GB)
- **GPU acceleration** przez DirectML (działa z NVIDIA, AMD, Intel)
- **Auto-update** - sprawdzanie raz na 24h + one-click "Pobierz i zainstaluj"
- **DuplicateAppFinder** - sprzątanie starych kopii .exe z Pulpitu, Pobranych itp.
- **Native Windows Toast notifications** dla update available
- **Launch at login** przez wpis HKCU\\Run (bez UAC)
- **Hallucination filter** odrzuca typowe halucynacje Whisper przy ciszy

### Architektura

- WinUI 3 (Windows App SDK 1.5) + .NET 8
- Whisper.net 1.5 (binding do whisper.cpp)
- NAudio 2.2 (audio capture)
- SharpHook 5.3 (global keyboard hooks)
- TextCopy + InputSimulator (auto-paste)
- Microsoft.Data.Sqlite + JSON settings
- Serilog rolling files
- xUnit + FluentAssertions + Moq dla testów

### Prywatność

- Zero telemetrii, zero historii transkrypcji
- Połączenia sieciowe TYLKO do `huggingface.co` (modele) i `api.github.com` (update check)
- Audytowalność: pełen kod źródłowy publiczny na GitHub

### Co NIE jest w v0.1.0 (planowane na przyszłość)

- Microsoft Store distribution (po v1.0, opcjonalne)
- Winget package (po v1.0, opcjonalne)
- Code signing (start z self-signed, paid cert kiedyś jeśli >100 userów)
- Lokalizacja interfejsu (na razie tylko polski)

---

**Repo**: https://github.com/marcinwerner/polskiwhisper.pl
**Wersja macOS**: zobacz [../CHANGELOG.md](../CHANGELOG.md)
