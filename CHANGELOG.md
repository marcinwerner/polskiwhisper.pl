# Changelog

Format zgodny z [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [Semantic Versioning](https://semver.org/lang/pl/).

## [0.1.1] - 2026-05-05

Release naprawowy - poprawki bezpieczeństwa, jakości życia i uproszczenie aplikacji.

### Naprawione

- **Halucynacja przy ciszy** - po taptnięciu i braku mowy aplikacja wklejała frazy
  typu "Dziękuję za oglądanie" / "Subskrybujcie" (Whisper trenowany na YouTube
  outros). Teraz przed transkrypcją sprawdzamy maksymalny RMS audio - jeśli było
  cicho, nie wywołujemy Whispera w ogóle. Cisza = nic się nie wkleja.
- **Klik w ikonę w Docku** otwiera teraz Ustawienia (wcześniej nic się nie działo)
- **Filter halucynacji odporny na warianty bez polskich znaków** - "Dziekuje za
  ogladanie" jest łapane tak samo jak "Dziękuję za oglądanie"

### Bezpieczeństwo / prywatność

- Logger nie wycieka treści transkrypcji ani słownictwa do unified log macOS.
  Wcześniej `os.Logger` z `privacy: .public` mógł logować surowy tekst (gdy
  filter halucynacji ucinał coś z transkrypcji) oraz custom words / find&replace
  rules / AI vocab terms. Teraz logujemy tylko długości / id / metadata.
  Deklaracja prywatności w `Logger.swift` zgadza się z faktycznym kodem.
- Usunięte zbędne uprawnienie `com.apple.security.automation.apple-events`
  i `NSAppleEventsUsageDescription` z Info.plist - aplikacja faktycznie ich
  nie używa (CGEvent.post na .cghidEventTap nie wymaga Apple Events)

### Usunięte

- **Integracja z Ollama / Bielik 11B / inne lokalne LLM-y** - post-processing
  przez LLM (zakładka "Model AI" w Ustawieniach) został usunięty. Domyślnie był
  wyłączony, Whisper Turbo daje wystarczającą jakość po polsku. Mniejszy kod,
  prostszy UX. Jeśli kiedyś polish potrzebny - można przywrócić z git history.
- Nieużywana dependency `KeyboardShortcuts` (custom `ModifierKeyMonitor` ją
  zastąpił od początku) - mniejszy DMG, mniejszy attack surface

### Zmienione

- README zawiera obraz hero + opis bez wzmianek o LLM
- Pipeline transkrypcji: 3 kroki (Whisper → Vocabulary → Paste) zamiast 4

## [0.1.0] - 2026-05-05

Pierwszy publiczny release. Aplikacja jest funkcjonalna i stabilna - gotowa do osobistego użycia oraz dystrybucji prywatnej.

### Dodane

#### Funkcjonalność rdzeniowa
- **Promptowanie głosowe** w pełni offline - tap, mów po polsku, tap, tekst się wkleja
- **Whisper Turbo** (`large-v3-v20240930_547MB`) - 547 MB, optymalizowany pod polski
- **WhisperKit** + Apple Neural Engine + Metal (CoreML) - szybka transkrypcja
- **Auto-paste** przez Cmd+V w aktywnej aplikacji macOS
- **Anti-halucynacja** - 4 thresholdy + filter list 25+ typowych YouTube outros (PL+EN)

#### Hotkey + tryb
- 5 opcji hotkey: Lewy/Prawy Option, Lewy/Prawy Command, Fn
- 2 tryby: Przełącznik (toggle) lub Przytrzymanie (push-to-talk)
- Live re-init monitor po zmianie w Settings
- Ostrzeżenie o kolizji z polskimi znakami (Option na PL keyboard layout)

#### Słownictwo (3 warstwy)
- **Słowa własne** - boost rozpoznawania nazw własnych (Whisper initialPrompt)
- **Znajdź i zamień** - reguły zamiany tekstu (text + regex + case-sensitive)
- **Słownik AI** - terminy do system promptu LLM
- Eksport / import JSON dla backup i migracji
- Persistencja w GRDB SQLite (`~/Library/Application Support/PolskiWhisper/vocabulary.db`)

#### Opcjonalne oczyszczanie tekstu (LLM)
- Integracja z Ollama (HTTP localhost:11434)
- 5 modeli do wyboru: Bielik 11B (Q4/Q5), Llama 3.2 3B, Phi 3.5, Qwen 2.5 14B
- System prompt z zabezpieczeniem anti-prompt-injection (XML wrapper `<DANE>`)
- Custom override system prompt
- Default OFF (opt-in)

#### UI
- **Real-time waveform** u góry ekranu (80 bars, scrolling, kolor reaguje na peak)
- **Onboarding** 6 kroków przy pierwszym uruchomieniu
- **Settings** w 5 zakładkach (Ogólne, Whisper, Model AI, Słownictwo, O programie)
- **Menu bar** ikona statusowa z dynamiczną informacją (gotowy / nagrywanie / pobieranie / ...)
- **Dock toggle** - opcja pokazania ikony w Docku (jak Superwhisper) lub tylko menu bar
- **Pełen polski UI** (CFBundleDevelopmentRegion: pl)
- **Dźwięki feedback** - "Pop" przy starcie, "Tink" przy wklejeniu (default ON)
- **App icon** - czarne tło + biało-czerwony waveform z neon glow

#### Konfiguracja
- Maksymalny czas nagrywania (1 min - bez limitu)
- Autostart przy logowaniu (LaunchAtLogin)
- Auto-paste on/off
- Wybór modelu Whisper (7 opcji od Tiny do Large v3) z progress bar pobierania
- Wybór modelu LLM
- Reset wszystkich ustawień
- Pokaż onboarding ponownie

#### Prywatność
- **Zero telemetrii** - hardcoded URLs do localhost + huggingface.co (audytowalne przez `grep`)
- **Brak konta** - aplikacja nie wymaga rejestracji
- **Audio temp** w `~/Library/Caches/PolskiWhisper/` kasowane po success paste
- **Audio format** 16 kHz Int16 mono (~6x mniej miejsca niż native przez AVAudioConverter)
- **Crash recovery** - orphan WAV detection + cleanup przy starcie

#### Dokumentacja
- README po polsku z badges, performance numbers, privacy section
- INSTALL.md - krok-po-kroku instalacja + ominięcie Gatekeeper
- PRIVACY.md - audytowalna polityka prywatności
- ARCHITECTURE.md - struktura kodu, flow danych
- ROADMAP.md - plan rozwoju
- DEVELOPMENT.md - setup dev environment
- ACKNOWLEDGEMENTS.md - lista OSS components z licencjami
- CHANGELOG.md - historia wersji
- CONTRIBUTING.md - wytyczne dla kontrybutorów
- SECURITY.md - polityka zgłaszania luk bezpieczeństwa

#### Build system
- XcodeGen (project.yml jako single source of truth, .xcodeproj generowane)
- Self-signed code signing certificate dla stabilnej signature między buildami
- scripts/setup.sh - bootstrap dla nowych klonów
- scripts/regenerate.sh - regeneracja po zmianach project.yml
- scripts/build.sh - command line build (Debug/Release)
- scripts/build-dmg.sh - tworzy DMG installer

### Znane ograniczenia
- **Brak Apple Developer ID signing** ($99/rok nie kupowane) → users musi raz omijać "unidentified developer" warning (right-click → Otwórz)
- **Brak notarization** - dla public Mac App Store dystrybucja wymagana
- **Brak auto-update** (Sparkle wymaga code signing)
- **Brak Intel support** - tylko Apple Silicon (WhisperKit wymaga ANE)
- **macOS 14+ only** (Sonoma, Sequoia, Tahoe)
- **Bielik 11B na M1 16GB** dodaje znaczące opóźnienie do dyktowania (zalecane wyłączenie LLM lub lżejszy model jak Llama 3.2 3B / Phi 3.5)

### Statystyki
- 27 plików Swift, ~5200 linii kodu
- 11 dependencies SPM (Swift Package Manager)
- Build size: ~19 MB unpacked, ~7 MB DMG
- Whisper model: 547 MB (pobierany przy pierwszym użyciu z Hugging Face)

[0.1.0]: https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/v0.1.0
