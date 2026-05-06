# Changelog

Format zgodny z [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [Semantic Versioning](https://semver.org/lang/pl/).

## [0.1.2] - 2026-05-07

Kolejna iteracja PolskiWhisper z usprawnieniami zgłoszonymi przez pierwszych użytkowników.

### Nowości

- **Automatyczne odstępy między zdaniami** - gdy dyktujesz na raty (zdanie, chwila przerwy, kolejne zdanie), aplikacja sama zadba o spację po kropce. Zamiast "Pierwsze zdanie.Drugie zdanie" dostajesz "Pierwsze zdanie. Drugie zdanie".
- **Lepsze info podczas dłuższych transkrypcji** - jeśli model potrzebuje chwili na większe nagranie, widget pokazuje że pracuje, żeby było wiadomo że wszystko idzie zgodnie z planem.

### Usprawnienia

- **Bardziej niezawodny słownik własny** - aplikacja lepiej radzi sobie z nietypowymi nazwami w słowniku i zawsze dostarcza transkrypcję.
- **Szybsze zamykanie widgetu** - okienko dyktowania znika natychmiast po zakończeniu nagrywania, bez zbędnego oczekiwania.
- **Aplikacja sama reaguje gdy coś się przedłuża** - jeśli transkrypcja trwa wyjątkowo długo, aplikacja przyjaźnie wraca do gotowości zamiast czekać w nieskończoność.

### Zmiany w interfejsie

- **Zakładka "Słownik"** zamiast "Słownictwo" - krótsza i czytelniejsza nazwa.
- **Polskie nazwy w słowniku** - "Wzorzec zaawansowany" zamiast "Regex", "Rozróżniaj wielkie i małe litery" zamiast "Case sensitive". Plus podpowiedzi po polsku co która opcja robi.
- **Uproszczona zakładka słownika** - wszystko w jednym miejscu (Znajdź i zamień). Dla większości użytkowników to wystarcza w 100%. Twoje wcześniejsze wpisy ze starszej zakładki "Słowa własne" wciąż wspomagają rozpoznawanie w tle.
- **Czytelniejsze logi diagnostyczne** - dla osób debugujących, więcej informacji o tym co Whisper zwraca przed filtrowaniem.

### Aktualizacja z v0.1.1

Twój słownik, ustawienia i pobrany model Whisper zostają na miejscu. Pobierz DMG, przeciągnij do Aplikacji - aplikacja sama zauważy nową wersję i zaproponuje restart.

## [0.1.1] - 2026-05-05

Release naprawowy + nowe features dla update flow. Poprawki bezpieczeństwa,
jakości UX, uproszczenie aplikacji.

### Naprawione

- **Halucynacja przy ciszy** - po taptnięciu i braku mowy aplikacja wklejała frazy
  typu "Dziękuję za oglądanie" / "Subskrybujcie" (Whisper trenowany na YouTube
  outros). Teraz przed transkrypcją sprawdzamy maksymalny RMS audio - jeśli było
  cicho, nie wywołujemy Whispera w ogóle. Cisza = nic się nie wkleja.
- **Bug "Już trwa nagrywanie"** - state desynchronization między audio engine
  a fazą aplikacji prowadziło do stuck state gdzie tap dawał błąd zamiast
  zatrzymać nagrywanie (user musiał force-quit). Defense in depth na 3 poziomach
  (isDictating, startDictation recovery, AudioRecorder self-healing).
- **Pasek pobierania zatrzymywał się na 90%** - WhisperKit init nie ma progress
  callback, więc po download (0-90%) load do RAM (5-30s) wyglądał jak zawieszenie.
  Teraz UI rozróżnia 2 fazy: download (rzeczywisty pasek 0-100% z procentem)
  vs loadingToRAM (indeterminate spinner z komunikatem "Ładowanie do pamięci").
- **Klik w ikonę w Docku** otwiera teraz ZAWSZE Ustawienia, niezależnie od stanu
  okna (zminimalizowane, na innym desktopie, w tle - wszędzie deminiaturize +
  bring to front)
- **Filter halucynacji odporny na warianty bez polskich znaków** - "Dziekuje za
  ogladanie" / "Subskrybujcie kanal" są łapane tak samo jak wersje z ogonkami.
  Plus poprawiona obsługa "ł" (Unicode U+0142, nie diakrytyk) przez manual fold

### Dodane

- **Domyślny model: Whisper Turbo 1.5 GB** zamiast 547 MB - znacząco lepsza
  jakość rozpoznawania polskiego. Aktualni userzy z UserDefaults zostają na
  swoim wyborze (manual change w Settings → Whisper).
- **Cleanup poprzedniego modelu** - przy zmianie modelu w Settings, jeśli
  poprzedni jest na dysku, dialog: "Usunąć poprzedni model X (Y MB)?"
  oszczędność miejsca (do ~3 GB dla Large v3)
- **In-app update checker** - aplikacja sprawdza GitHub Releases API raz na
  24h. Jeśli dostępna nowa wersja: banner w Settings → Ogólne + badge w menu
  bar dropdown. Tylko publiczny GitHub API, brak personal data, brak telemetrii.
- **Self-update detection** - aplikacja wykrywa gdy user podmieni .app w
  /Applications/ (pobierze DMG i przeciągnie). Sprawdza mtime co 60s. Pierwsza
  detekcja: modal alert "Restart aplikacji"/"Później". Po "Później": badge
  w menu bar z button "Restart aplikacji" (relaunch + terminate)
- **Circular progress ring** wokół ikony pobierania w floating window - user
  widzi konkretny progress 0-100% wokół ikony (orange ring), a podczas load
  do RAM widzi spinner z ikoną pamięci

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

- README zawiera obraz hero + opis bez wzmianek o LLM, dokładne liczby modeli
- Pipeline transkrypcji: 3 kroki (Whisper → Vocabulary → Paste) zamiast 4
- Wymagania dyskowe w README: ~1.5 GB dla domyślnego modelu (do 3 GB dla Large v3)

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
