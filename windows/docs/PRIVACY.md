# Polityka prywatności - PolskiWhisper Windows

> **TL;DR**: Aplikacja działa w pełni offline. Twoje nagrania, transkrypcje i słownik nigdy nie opuszczają komputera.

## Co aplikacja robi z Twoimi danymi?

### Twoje audio (nagrania głosu)

- **Nagrania trafiają tylko do tymczasowego pliku WAV** w `%LOCALAPPDATA%\PolskiWhisper\temp\`.
- **Nigdy nie wysyłane do internetu.**
- **Plik jest kasowany automatycznie** zaraz po wklejeniu transkrypcji (lub gdy anulujesz przez Esc).
- Whisper przetwarza WAV **lokalnie** - silnik whisper.cpp działa na CPU/GPU Twojego komputera.

### Transkrybowany tekst

- **Tekst trafia bezpośrednio do schowka systemowego** + symuluje Ctrl+V do aktywnego okna.
- **Aplikacja nie zapisuje historii transkrypcji** - po wklejeniu nie ma żadnego śladu w jakimkolwiek pliku.
- Schowek jest globalnym mechanizmem Windows, więc inne aplikacje teoretycznie mogłyby go odczytać (jak każdy clipboard) - aplikacja nie kontroluje co dzieje się ze schowkiem po wklejeniu.

### Słownik (Find & Replace)

- Twoje reguły są zapisywane w lokalnej bazie SQLite: `%LOCALAPPDATA%\PolskiWhisper\vocabulary.db`.
- **Nie wysyłane nigdzie** - tylko Twój komputer.

### Konfiguracja

- Plik JSON: `%LOCALAPPDATA%\PolskiWhisper\settings.json`.
- Zawiera: wybrany model Whisper, hotkey, dźwięki, autostart, etc.
- **Nie zawiera żadnych danych użytkownika** - tylko preferencje aplikacji.

## Połączenia sieciowe - dokładna lista

Aplikacja łączy się z **dwoma adresami** internetowymi i niczym więcej:

### 1. Hugging Face - pobieranie modelu Whisper

- **URL**: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-*.bin`
- **Kiedy**: tylko podczas pobierania modelu (przy first install lub gdy zmienisz model w Ustawieniach).
- **Co wysyłane**: standardowy HTTP GET request - User-Agent, IP (jak każda strona).
- **Co pobierane**: plik modelu (75 MB - 3 GB w zależności od wyboru).

### 2. GitHub Releases API - sprawdzanie aktualizacji

- **URL**: `https://api.github.com/repos/marcinwerner/polskiwhisper.pl/releases?per_page=20`
- **Kiedy**: raz na 24h (jeśli włączyłeś sprawdzanie aktualizacji w Ustawieniach), oraz gdy klikniesz "Sprawdź teraz".
- **Co wysyłane**: standardowy HTTP GET request - User-Agent ("PolskiWhisperWin/0.1.0"), IP.
- **Co pobierane**: lista metadanych release-ów (nazwy, daty, URL-e do MSI). **Nie żadne Twoje dane** - tylko pytanie "jaka jest najnowsza wersja?".

### Pobieranie installerа (jeśli aktualizujesz)

- **URL**: `https://github.com/marcinwerner/polskiwhisper.pl/releases/download/win-vX.Y.Z/PolskiWhisper-X.Y.Z-win-x64.msi`
- **Kiedy**: tylko gdy klikniesz "Pobierz i zainstaluj" przy dostępnej aktualizacji.

## Co aplikacja **NIE** robi?

- ❌ **Nie wysyła telemetrii** - zero analytics, zero crash reporters
- ❌ **Nie phone-home** - aplikacja nigdy nie kontaktuje się z serwerem autora
- ❌ **Nie zbiera anonimizowanych statystyk użytkowania**
- ❌ **Nie korzysta z chmurowego API speech-to-text** (jak Google Cloud, Azure, OpenAI Whisper API)
- ❌ **Nie zapisuje historii transkrypcji** ani nagrań na dysku trwale
- ❌ **Nie czyta innych plików na dysku** poza własnym folderem `%LOCALAPPDATA%\PolskiWhisper\`
- ❌ **Nie integruje się z social media, ad networks, third-party SDK**

## Audytowalność

**Pełen kod źródłowy aplikacji jest publiczny** na GitHub: https://github.com/marcinwerner/polskiwhisper.pl

Możesz samodzielnie sprawdzić każde wywołanie sieciowe - wystarczy:

```powershell
# Wszystkie miejsca w kodzie używające HttpClient (powinny być tylko 2 - Whisper download i UpdateChecker).
git grep -n "HttpClient\|HttpClientFactory" windows/src/

# Sprawdź konkretne URL-e.
git grep -n "huggingface.co\|api.github.com" windows/src/
```

Każde wywołanie sieciowe jest **opisane komentarzem** wyjaśniającym co i dlaczego.

## Code signing

PolskiWhisper Windows używa **self-signed certyfikatu** (świadoma decyzja - "stable hobby project, no premium polished").
Oznacza to:

- Windows SmartScreen może pokazać ostrzeżenie "Unknown Publisher" przy pierwszej instalacji
- Aplikacja nie jest **zweryfikowana** przez certyfikat zaufanego CA jak Sectigo lub DigiCert

Jeśli to dla Ciebie ważne:
- **Zweryfikuj checksum** pobranego MSI z opisu release na GitHub
- **Zbuduj samodzielnie ze źródeł** (`scripts/build.ps1`)
- **Uruchom we wirtualnej maszynie** dla testów przed zainstalowaniem na main system

## Twoje prawa

Ponieważ aplikacja **nie zbiera, nie przechowuje, ani nie przetwarza Twoich danych poza Twoim komputerem**, większość regulacji privacy nie ma zastosowania (RODO/GDPR, CCPA itp.) - po prostu nie ma żadnych Twoich danych po naszej stronie.

Wszystkie Twoje dane (nagrania-które-są-natychmiast-kasowane, transkrypcja-która-trafia-do-schowka, słownik, konfiguracja) są w Twoich rękach na Twoim komputerze. Zawsze możesz:

- **Usunąć dane**: skasuj folder `%LOCALAPPDATA%\PolskiWhisper\` lub odinstaluj aplikację.
- **Wyeksportować słownik**: skopiuj plik `vocabulary.db`.
- **Audytować ruch sieciowy**: użyj Wireshark / Fiddler i potwierdź że aplikacja kontaktuje się tylko z huggingface.co i api.github.com.

## Kontakt w sprawach prywatności

[kontakt@marcinwerner.com](mailto:kontakt@marcinwerner.com)

---

**Ostatnia aktualizacja**: 2026-05-08 (wersja v0.1.0 dokumentu)
**Wersja macOS**: [../../docs/PRIVACY.md](../../docs/PRIVACY.md)
