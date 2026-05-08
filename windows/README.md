# PolskiWhisper na Windows

> Darmowa, otwartoźródłowa aplikacja do dyktowania głosowego po polsku.
> Działa w pełni offline po pobraniu modelu Whisper.

[![Windows CI](https://github.com/marcinwerner/polskiwhisper.pl/actions/workflows/windows-ci.yml/badge.svg)](https://github.com/marcinwerner/polskiwhisper.pl/actions/workflows/windows-ci.yml)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](../LICENSE)

PolskiWhisper to natywna aplikacja Windows (siostra macOS-owej wersji) zbudowana na **WinUI 3 + C# + Whisper.net**.
Pozwala dyktować po polsku w dowolnej aplikacji - naciskasz skrót klawiszowy, mówisz, tekst pojawia się tam gdzie kursor.

## Co to robi?

a) **Dyktowanie po polsku** w dowolnej aplikacji (e-mail, edytor, formularz w przeglądarce)
b) **W pełni offline** po pobraniu modelu - nagrania nie opuszczają komputera
c) **Konfigurowalny słownik** Find & Replace dla nazw własnych
d) **Auto-spacja** po `.!?` przy nagrywaniu na raty
e) **Esc** anuluje nagrywanie bez wklejania
f) **System tray** - aplikacja chodzi w tle, dostępna pod skrótem klawiszowym

## Jak zacząć

a) Pobierz najnowszy MSI z [Releases](https://github.com/marcinwerner/polskiwhisper.pl/releases)
b) Zainstaluj (per-user, bez UAC). Jeśli SmartScreen pokazuje ostrzeżenie - patrz [docs/INSTALL.md](docs/INSTALL.md)
c) Przy pierwszym uruchomieniu przejdź onboarding (5 kroków)
d) Pobierz model Whisper Turbo (1.5 GB) - jednorazowo
e) Naciśnij prawy Ctrl, mów, naciśnij ponownie - tekst pojawi się tam gdzie kursor

## Wymagania

- Windows 10 1809+ lub Windows 11
- ~4 GB RAM wolnego
- ~2 GB miejsca na dysku (dla modelu)
- Mikrofon
- (opcjonalnie) GPU z DirectX 12 dla DirectML acceleration

## Filozofia projektu

**Stabilny hobby project, nie premium polished.** Bez Microsoft Store fee, bez telemetrii, bez phone-home.
Aplikacja audytowalna - kod publiczny na GitHub, polityka prywatności w [docs/PRIVACY.md](docs/PRIVACY.md).

## Stos technologiczny

- **UI**: WinUI 3 (Windows App SDK 1.5)
- **Język**: C# 12 / .NET 8
- **Speech-to-text**: Whisper.net (binding do whisper.cpp z DirectML GPU)
- **Audio capture**: NAudio
- **Hotkey**: SharpHook (low-level keyboard hook)
- **Auto-paste**: TextCopy + InputSimulator
- **Persystencja**: Microsoft.Data.Sqlite + JSON
- **Logging**: Serilog
- **Tests**: xUnit + FluentAssertions + Moq

Pełna architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Build i development

Wymagania:
- Visual Studio 2022 (Community OK) lub `dotnet` CLI
- .NET 8 SDK
- Windows App SDK 1.5+
- (do MSI) WiX 4: `dotnet tool install --global wix`

```powershell
# Build + uruchom
.\scripts\build.ps1

# Build + testy
.\scripts\build.ps1 -RunTests

# Build + publish (self-contained)
.\scripts\build.ps1 -Configuration Release -Publish

# MSI installer (po publish)
.\scripts\build-installer.ps1 -Version 0.1.0
```

## Struktura projektu

```
windows/
├── PolskiWhisperWin.sln          # Visual Studio solution
├── src/
│   ├── PolskiWhisperWin/         # Main app (WinUI 3)
│   ├── PolskiWhisperWin.Core/    # Business logic (testowalny, bez UI)
│   └── PolskiWhisperWin.Tests/   # xUnit unit tests
├── installer/                    # WiX MSI definition
├── scripts/                      # PowerShell build/release scripts
├── docs/                         # Public documentation
└── README.md
```

## Pełna parytet z macOS-ową wersją

| Funkcja | macOS | Windows |
|---|---|---|
| Hotkey toggle/hold | ✅ | ✅ |
| Esc cancel | ✅ | ✅ |
| Auto-spacing po `.!?` | ✅ | ✅ |
| Floating waveform window | ✅ | ✅ |
| 9 dźwięków (start/finish) | ✅ | ✅ |
| Whisper Turbo default | ✅ | ✅ |
| Find & Replace słownik (drag-drop) | ✅ | ✅ |
| Hallucination filter | ✅ | ✅ |
| Auto-update (one-click) | ✅ | ✅ |
| DuplicateAppFinder | ✅ | ✅ |
| Native notifications (Toast) | ✅ | ✅ |
| Onboarding wizard | ✅ | ✅ |
| Launch at login | ✅ | ✅ |
| GPU acceleration | Apple Silicon ANE | DirectML |

## Kontakt

- Email: [kontakt@marcinwerner.com](mailto:kontakt@marcinwerner.com)
- Issues: [GitHub Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues)
- Strona: [polskiwhisper.pl](https://polskiwhisper.pl)

## Licencja

[MIT](../LICENSE) - możesz robić praktycznie wszystko z tym kodem, bez gwarancji.

---

**Współpraca**: [CONTRIBUTING.md](../CONTRIBUTING.md) (wspólne dla obu platform)
**Bezpieczeństwo**: [SECURITY.md](../SECURITY.md)
**Wersja macOS**: [../README.md](../README.md)
