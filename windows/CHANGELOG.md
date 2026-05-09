# Changelog - PolskiWhisper Windows

Wszystkie znaczące zmiany w wersji Windows. Format na podstawie [Keep a Changelog](https://keepachangelog.com).

> **Wersjonowanie**: tagi w git mają prefix `win-` (np. `win-v0.1.0-preview`), żeby rozróżnić od macOS (`v0.1.5`). Numeracja Windows niezależna od macOS.

## [0.1.0-preview] - 2026-05-09

**Pierwszy publiczny pre-release Windows.** Placeholder UI - testowa wersja sprawdzająca czy aplikacja w ogóle uruchamia się na Windows. Pełne UI z dyktowaniem zaplanowane na `v0.2.0` po feedbacku testerów.

### Co działa

- ✅ Aplikacja kompiluje się i startuje na Windows 10 1809+ / Windows 11
- ✅ Okno z napisem "PolskiWhisper v0.1.0" + numer wersji
- ✅ Self-contained .NET 8 + Windows App SDK runtime w ZIP (113 MB) - zero dependencies do instalacji
- ✅ Logger Serilog do `%LOCALAPPDATA%\PolskiWhisper\logs\` (rolling daily, 7 dni retencji)
- ✅ Single-instance check przez named Mutex
- ✅ Crash handler z friendly dialog przy startup failure
- ✅ Hotkey monitor (SharpHook) - skompilowany, nie testowany runtime
- ✅ Audio recorder (NAudio) - skompilowany, nie testowany runtime
- ✅ Whisper.net wrapper - skompilowany, nie testowany runtime (brak modelu)

### Co jest w kodzie ale tymczasowo wyłączone

XamlCompiler na CI runner nie raportuje konkretnych błędów dla complex XAML pages. Aktywacja po debugu lokalnym w Visual Studio 2022. W tej wersji wyłączone w `csproj`:

- 4 zakładki Settings (Ogólne, Whisper, Słownik, O programie)
- FloatingDictationWindow z waveform animation
- OnboardingWindow + 5 kroków first-run wizard
- TrayIconController (system tray icon)
- NotificationDispatcher (Windows Toast)
- SoundService (9 dźwięków systemowych)

### Architektura

- **UI**: WinUI 3 (Windows App SDK 1.5.240627000)
- **Język**: C# 12 / .NET 8 LTS (8.0.420)
- **Speech-to-text**: Whisper.net 1.5.0 (binding do whisper.cpp z DirectML GPU)
- **Audio**: NAudio 2.2.1
- **Hotkey**: SharpHook 5.3.7
- **Auto-paste**: TextCopy 6.2.1 + InputSimulatorPlus 1.0.7
- **Persystencja**: Microsoft.Data.Sqlite 8.0.4 + JSON
- **Logging**: Serilog 3.1.1 + Serilog.Enrichers.Thread 3.1.0
- **Tests**: xUnit 2.7.1 + FluentAssertions 6.12.0 + Moq 4.20.70

### Distribution

- **GitHub Releases**: https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/win-v0.1.0-preview
- **Direct download** (no login): https://github.com/marcinwerner/polskiwhisper.pl/releases/download/win-v0.1.0-preview/PolskiWhisper-0.1.0-preview-win-x64.zip
- **SHA256**: `274a202a97979fd4fcd662ec9fe5238f6340380512e4324d384b3f162422d5a1`
- **Pre-release flag**: TAK (nie wyświetla się jako "Latest")

### Wymagania systemowe

- Windows 10 build 17763 (1809) lub Windows 11
- ~4 GB wolnego RAM
- ~500 MB miejsca na dysku
- Mikrofon (do późniejszego dyktowania w v0.2.0+)
- Opcjonalnie GPU z DirectX 12 (DirectML acceleration dla Whisper)

### Prywatność

- Zero telemetrii, zero historii transkrypcji
- Połączenia sieciowe: tylko `huggingface.co` (modele Whisper) + `api.github.com` (sprawdzanie aktualizacji)
- Audytowalność: pełen kod źródłowy publiczny na GitHub

Pełna polityka: [docs/PRIVACY.md](docs/PRIVACY.md)

### Co testować

Tester (Szymon Początko) sprawdza absolutne minimum:
1. Czy aplikacja się uruchomi
2. Czy zobaczy okno z napisem "PolskiWhisper"
3. Czy SmartScreen blokuje (i jak go obejść)
4. Czy crash → log w `%LOCALAPPDATA%\PolskiWhisper\logs\`

Pełny przewodnik: [docs/SZYMON_TEST.md](docs/SZYMON_TEST.md)

### Znane ograniczenia v0.1.0-preview

- Kliknięcie EXE pokazuje tylko placeholder okno - bez interakcji
- Brak dyktowania głosowego (kod jest, ale wyłączony w UI)
- Brak Settings UI
- Brak system tray icon
- Brak ikon (`AppIcon.ico` placeholder skomentowany w csproj)
- MSI installer nie jest budowany na CI (zarezerwowane na v0.2.0+)
- SmartScreen pokazuje "Unknown publisher" warning (self-signed cert, świadoma decyzja)

### Co dalej (v0.2.0+)

- Reaktywacja XAML pages w VS 2022 (lokalne debugowanie XamlCompiler)
- Brand assets (.ico, 9× .wav)
- Pierwszy MSI installer
- Aktywacja TrayIconController, NotificationDispatcher, SoundService
- Onboarding wizard
- Pełny pipeline dyktowania end-to-end
- Code signing (rozważone po >100 userach)

---

**Repo**: https://github.com/marcinwerner/polskiwhisper.pl
**macOS wersja**: [v0.1.5](https://github.com/marcinwerner/polskiwhisper.pl/blob/main/CHANGELOG.md)
