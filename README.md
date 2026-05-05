# PolskiWhisper

> Natywna macOS aplikacja do promptowania głosowego po polsku - w pełni lokalna, wolna, otwarta.

[![Release](https://img.shields.io/github/v/release/marcinwerner/polskiwhisper.pl?include_prereleases&label=pobierz&color=green)](https://github.com/marcinwerner/polskiwhisper.pl/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-blue)](https://support.apple.com/en-us/HT211814)
[![GitHub stars](https://img.shields.io/github/stars/marcinwerner/polskiwhisper.pl?style=social)](https://github.com/marcinwerner/polskiwhisper.pl/stargazers)

![PolskiWhisper](docs/screenshots/og-image.jpg)

PolskiWhisper to **darmowe, lokalne narzędzie do promptowania głosowego dla macOS**. Naciskasz klawisz, mówisz po polsku, naciskasz ponownie - tekst wkleja się w aktywnej aplikacji. Bez chmury, bez kont, bez subskrypcji. **Twoje słowa nie opuszczają komputera.**

## Co potrafi

- ✅ **Dyktowanie po polsku** z dokładnością Whisper Large-v3 Turbo (OpenAI, Sept 2024)
- ✅ **Działa wszędzie** - Notatki, Slack, Claude, przeglądarka, Mail, terminal
- ✅ **W pełni offline** po jednorazowym pobraniu modelu (~1.5 GB dla domyślnego Whisper Turbo)
- ✅ **Konfigurowalny hotkey** (lewy/prawy Option, Command, Fn) + tryb toggle/przytrzymanie
- ✅ **Słownictwo własne** - boost rozpoznawania nazw, reguły Find & Replace, eksport/import JSON
- ✅ **Real-time waveform** - widzisz na żywo poziom dźwięku podczas mówienia
- ✅ **Inteligentne wykrywanie ciszy** - jeśli nic nie powiesz, nic się nie wkleja
- ✅ **Zero telemetrii** - audytowalny kod, polski autor, MIT license

## Wymagania

| | |
|---|---|
| **macOS** | 14 Sonoma lub nowszy |
| **Procesor** | Apple Silicon (M1/M2/M3/M4) - Intel nie wspierany |
| **RAM** | 8 GB |
| **Dysk** | ~1.5 GB na domyślny model Whisper (do 3 GB jeśli wybierzesz Large v3) |
| **Mikrofon** | wbudowany lub zewnętrzny |

## Instalacja

📥 **[Pobierz najnowszą wersję z GitHub Releases](https://github.com/marcinwerner/polskiwhisper.pl/releases)** (plik `.dmg`)

Pełna instrukcja krok-po-kroku w [docs/INSTALL.md](docs/INSTALL.md), włącznie z:
- Jak ominąć "unidentified developer" warning (aplikacja nie jest podpisana certyfikatem Apple - autor nie kupuje $99/rok)
- Konfiguracja uprawnień (mikrofon + Dostępność)
- Pierwsze użycie

## Jak to działa

```
        🎤 Mówisz (wybrany hotkey)
                       ↓
        AVAudioEngine - real-time RMS waveform
                       ↓
        Wykrywanie ciszy (jeśli cicho - skip, nic się nie wkleja)
                       ↓
        WhisperKit + Whisper Turbo (CoreML, Apple Neural Engine)
        Język: pl (wymuszony)
                       ↓
        Custom Words (Twój słownik) + Find & Replace
                       ↓
        Schowek + auto-paste (Cmd+V) w aktywnej aplikacji
```

**Performance** (zmierzone na MacBook Pro M1 16GB):
- Whisper transcribe 9s mowy: **~1.5s**
- Load modelu z cache do RAM: **~1s**
- Pierwsze pobranie modelu: 3-8 min (zależy od internetu, ~1.5 GB dla domyślnego)

## Prywatność (architectural, nie marketingowa)

PolskiWhisper łączy się z internetem **TYLKO** w jednym przypadku:

1. **Pobieranie modelu Whisper** - przy pierwszym użyciu (Hugging Face, plik publiczny)

**Nigdzie indziej.** Żadnych analytics, telemetrii, "phone home", crash reportów do chmury. Audyt kodu trywialny:

```bash
grep -rn "URLSession\|URLRequest" PolskiWhisper/Sources/
```

Pełen opis: [docs/PRIVACY.md](docs/PRIVACY.md). Architektura jest read-only-friendly - każdy może sprawdzić.

## Konfiguracja

Po instalacji ikona mikrofonu pojawia się w pasku menu (prawy górny róg ekranu). **Cmd+,** lub kliknięcie ikony → "Otwórz Ustawienia..." otwiera 5 zakładek:

- **Ogólne** - hotkey, tryb (toggle/przytrzymanie), max czas nagrywania, dźwięki, autostart
- **Whisper** - wybór modelu (7 opcji: tiny → large-v3, z statusem pobrania i progress bar)
- **Słownictwo** - Custom Words, Find & Replace, Słownik AI + eksport/import JSON
- **O programie** - wersja, licencje OSS, reset ustawień, ponowny onboarding

## Stack technologiczny

| Komponent | Co | Licencja |
|---|---|---|
| Whisper engine | [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML + Apple Neural Engine) | Apache 2.0 |
| Hotkey | NSEvent + custom modifier-tap detection | własny |
| Persistence | [GRDB.swift](https://github.com/groue/GRDB.swift) (SQLite) | MIT |
| LaunchAtLogin | [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | MIT |

Pełna lista w [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## Dla deweloperów

```bash
git clone https://github.com/marcinwerner/polskiwhisper.pl.git
cd polskiwhisper.pl
./scripts/setup.sh        # bootstrap (xcodegen + SPM resolve)
open PolskiWhisper.xcodeproj
# Cmd+R w Xcode
```

Pełna dokumentacja:
- [CHANGELOG.md](CHANGELOG.md) - historia wersji
- [CONTRIBUTING.md](CONTRIBUTING.md) - wytyczne dla kontrybutorów
- [SECURITY.md](SECURITY.md) - polityka zgłaszania luk
- [docs/INSTALL.md](docs/INSTALL.md) - instrukcja instalacji dla użytkowników
- [docs/PRIVACY.md](docs/PRIVACY.md) - polityka prywatności

## Licencja

[MIT](LICENSE) - rób co chcesz, byle zachować copyright notice. Free to use, modify, redistribute - włącznie z komercyjnym użyciem.

PolskiWhisper jest budowany na ramieniu olbrzymów. Zobacz [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## Wsparcie

- 🐛 [GitHub Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues) - bug reporty i feature requesty
- 💬 [Dyskusje](https://github.com/marcinwerner/polskiwhisper.pl/discussions) - pytania, sugestie

---

**Status**: ✅ v0.1 - MVP gotowy do użycia. Funkcjonalny, stabilny, polski.

*PolskiWhisper © 2026 Marcin Werner. Aplikacja jest darmowa i open source.*
