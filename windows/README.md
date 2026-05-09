# PolskiWhisper na Windows

> Darmowa, otwartoźródłowa aplikacja do dyktowania głosowego po polsku.
> Działa w pełni offline po pobraniu modelu Whisper.

[![Windows CI](https://github.com/marcinwerner/polskiwhisper.pl/actions/workflows/windows-ci.yml/badge.svg)](https://github.com/marcinwerner/polskiwhisper.pl/actions/workflows/windows-ci.yml)
[![Pre-release](https://img.shields.io/badge/pobierz-v0.1.0--preview-orange)](https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/win-v0.1.0-preview)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](../LICENSE)

PolskiWhisper na Windows to siostra macOS-owej wersji zbudowana na **WinUI 3 + C# + Whisper.net + .NET 8**.
Pozwoli dyktować po polsku w dowolnej aplikacji - naciskasz skrót klawiszowy, mówisz, tekst pojawia się tam gdzie kursor.

## ⚠️ Status: pre-release v0.1.0-preview (testowa wersja)

Pierwsza publiczna kompilacja Windows ma **placeholder UI** - sprawdza tylko czy aplikacja w ogóle uruchamia się na Windows. Pełne UI z dyktowaniem przyjdzie w `v0.2.0` po feedbacku testerów.

**Co zobaczysz**: okno z napisem "PolskiWhisper v0.1.0" - i to wszystko w tej wersji.

## 📥 Pobierz pre-release

🔗 **Direct download (bez konta GitHub)**: [PolskiWhisper-0.1.0-preview-win-x64.zip](https://github.com/marcinwerner/polskiwhisper.pl/releases/download/win-v0.1.0-preview/PolskiWhisper-0.1.0-preview-win-x64.zip) - 113 MB

🔗 **Strona release**: [win-v0.1.0-preview](https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/win-v0.1.0-preview)

**SHA256**: `274a202a97979fd4fcd662ec9fe5238f6340380512e4324d384b3f162422d5a1`

## Jak uruchomić

1. Pobierz ZIP (link wyżej, ~113 MB)
2. Rozpakuj gdziekolwiek (np. Pulpit)
3. Dwa razy kliknij `PolskiWhisper.exe`
4. Pojawi się Windows SmartScreen "Windows protected your PC" - kliknij **"Więcej informacji"** → **"Uruchom mimo to"**

Pełen przewodnik: [docs/SZYMON_TEST.md](docs/SZYMON_TEST.md)

## Wymagania

- Windows 10 1809+ lub Windows 11
- ~4 GB wolnego RAM
- ~500 MB miejsca na dysku
- Mikrofon (do dyktowania w v0.2.0+)
- *(opcjonalnie)* GPU z DirectX 12 dla DirectML acceleration

## Filozofia projektu

**Stabilny hobby project, nie premium polished.** Bez Microsoft Store fee, bez telemetrii, bez phone-home. Aplikacja audytowalna - kod publiczny na GitHub, polityka prywatności w [docs/PRIVACY.md](docs/PRIVACY.md).

## Stos technologiczny

- **UI**: WinUI 3 (Windows App SDK 1.5)
- **Język**: C# 12 / .NET 8 LTS
- **Speech-to-text**: Whisper.net (binding do whisper.cpp z DirectML GPU)
- **Audio capture**: NAudio
- **Hotkey**: SharpHook (low-level keyboard hook)
- **Auto-paste**: TextCopy + InputSimulatorPlus
- **Persystencja**: Microsoft.Data.Sqlite + JSON
- **Logging**: Serilog
- **Tests**: xUnit + FluentAssertions + Moq

Pełna architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 🚧 Co jest tymczasowo wyłączone w v0.1.0-preview

XamlCompiler na CI runner nie raportuje konkretnych błędów dla complex XAML pages. Aktywacja po debugu lokalnym w Visual Studio 2022. Wyłączone w `csproj`:

- 4 zakładki Settings (Ogólne, Whisper, Słownik, O programie)
- FloatingDictationWindow + waveform
- OnboardingWindow + 5 kroków first-run wizard
- TrayIconController (system tray)
- NotificationDispatcher (Windows Toast)
- SoundService (9 dźwięków systemowych)

**Cały kod jest w repo** - aktywacja przez usunięcie `<Page Remove>` + `<Compile Remove>` w `windows/src/PolskiWhisperWin/PolskiWhisperWin.csproj`.

## Build i development

Wymagania:
- **Visual Studio 2022** (Community OK) - zalecane dla XAML debugowania
- *(lub)* `dotnet` CLI + .NET 8 SDK
- Windows App SDK 1.5+
- Windows 10/11

```powershell
# Build + run
.\scripts\build.ps1

# Build + tests
.\scripts\build.ps1 -RunTests

# Build + publish (self-contained ZIP)
.\scripts\build.ps1 -Configuration Release -Publish
```

W repo jest też GitHub Actions workflow w `.github/workflows/windows-ci.yml` - automatycznie buduje, testuje i tworzy artifact ZIP przy każdym push do main.

## Struktura projektu

```
windows/
├── PolskiWhisperWin.sln          # Visual Studio solution
├── src/
│   ├── PolskiWhisperWin/         # Main app (WinUI 3)
│   ├── PolskiWhisperWin.Core/    # Business logic (testowalny, bez UI)
│   └── PolskiWhisperWin.Tests/   # xUnit unit tests
├── installer/                    # WiX MSI definition (do v0.2.0+)
├── scripts/                      # PowerShell build/release scripts
├── docs/                         # Public documentation
└── README.md
```

## Roadmapa

| Wersja | Status | Zawartość |
|---|---|---|
| **v0.1.0-preview** | ✅ Released 2026-05-09 | Placeholder UI - pierwszy build Windows |
| **v0.2.0** | 🔜 ~2-4 tyg | Reaktywacja XAML pages + brand assets + pełny pipeline dyktowania |
| **v0.3.0** | 🔜 ~1-2 mies | MSI installer + auto-update |
| **v1.0.0** | 🔜 3-6 mies | Stable, parytet z macOS |

## Pełna parytet z macOS-ową wersją (target v1.0)

| Funkcja | macOS | Windows v0.1.0-preview | Windows v1.0 (target) |
|---|---|---|---|
| Hotkey toggle/hold | ✅ | 🟡 kod gotowy, niekompilowany | ✅ |
| Esc cancel | ✅ | 🟡 jw. | ✅ |
| Auto-spacing po `.!?` | ✅ | ✅ (Core compiled + tested) | ✅ |
| Floating waveform window | ✅ | 🟡 jw. | ✅ |
| 9 dźwięków (start/finish) | ✅ | 🟡 jw. | ✅ |
| Whisper Turbo default | ✅ | ✅ (Core compiled) | ✅ |
| Find & Replace słownik (drag-drop) | ✅ | 🟡 jw. | ✅ |
| Hallucination filter | ✅ | ✅ (tested) | ✅ |
| Auto-update (one-click) | ✅ | 🟡 jw. | ✅ |
| DuplicateAppFinder | ✅ | ✅ (compiled) | ✅ |
| Native notifications (Toast) | ✅ | 🟡 jw. | ✅ |
| Onboarding wizard | ✅ | 🟡 jw. | ✅ |
| Launch at login | ✅ | ✅ (compiled) | ✅ |
| GPU acceleration | Apple Silicon ANE | (kod gotowy) DirectML | DirectML |
| MSI installer | n/a | ❌ (v0.3.0+) | ✅ |
| Code signing | self-signed | self-signed | self-signed |

## Kontakt

- Email: [kontakt@marcinwerner.com](mailto:kontakt@marcinwerner.com)
- Issues: [GitHub Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues) (z prefixem `[Windows]`)
- Strona: [polskiwhisper.pl](https://polskiwhisper.pl)

## Licencja

[MIT](../LICENSE) - możesz robić praktycznie wszystko z tym kodem, bez gwarancji.

---

**Współpraca**: [CONTRIBUTING.md](../CONTRIBUTING.md) (wspólne dla obu platform)
**Bezpieczeństwo**: [SECURITY.md](../SECURITY.md)
**Wersja macOS**: [../README.md](../README.md) (v0.1.5 stabilna)
