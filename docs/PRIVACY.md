# Polityka prywatności PolskiWhisper

> Ten dokument opisuje **dokładnie** jakie dane są zbierane, gdzie są zapisywane i jakie połączenia sieciowe wykonuje aplikacja. Każde stwierdzenie tu jest weryfikowalne przez audyt kodu.

**Ostatnia aktualizacja**: 2026-05-05
**Wersja aplikacji**: 0.1.1

## TL;DR

- ✅ **Twoje słowa nie opuszczają Twojego komputera**. Cała transkrypcja dzieje się lokalnie
- ✅ **Brak konta**, brak loginu, brak ID urządzenia
- ✅ **Brak telemetrii**, brak analytics, brak crash reportingu, brak "anonymous usage stats"
- ✅ **Zero historii transkrypcji** - aplikacja nie zapisuje co dyktowałeś
- ⚠️ **Jedyny wyjątek**: pobieranie modelu Whisper z Hugging Face podczas onboardingu lub w Settings (zmiana modelu). To jest jednorazowe i transparentne

## Pełna lista połączeń sieciowych

PolskiWhisper wykonuje połączenia sieciowe **wyłącznie w jednym przypadku**:

### 1. Pobieranie modelu Whisper

**Kiedy**:
- Podczas onboardingu (pobierany domyślny model `large-v3-turbo`)
- Gdy w Settings → Whisper → Models zmienisz model lub klikniesz "Pobierz"

**Endpoint**: `https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main/...`

**Co jest wysyłane**: standard HTTPS GET request - nazwa modelu, nic ponadto. Zero ID urządzenia, zero "user agent" identyfikującego Cię.

**Co jest pobierane**: pliki wag modelu CoreML (`.mlmodelc` packages, ~1.5 GB dla domyślnego Whisper Turbo, do ~3 GB dla Large v3)

**Gdzie zapisane**: `~/Library/Caches/PolskiWhisper/whisper-models/`

**Weryfikacja**:
```bash
# Wszystkie miejsca w kodzie gdzie pobierany jest model:
grep -rn "huggingface.co" PolskiWhisper/
```

### 2. Co aplikacja **NIE robi**

❌ Brak wywołań do `polskiwhisper.pl` lub innych domen autora
❌ Brak Sentry, Firebase, Crashlytics, Mixpanel, Amplitude, Google Analytics
❌ Brak "phone home" przy starcie ani podczas używania
❌ Brak update checkera w wersji 0.x (Sparkle dodamy w Etap 5 - **opcjonalny, opt-in**, kontaktuje się tylko z `https://github.com/marcinwerner/polskiwhisper.pl/releases`)
❌ Brak DNS lookups w tle
❌ Brak websocket connections
❌ Brak SDK trackerów (zero zewnętrznych "behavioral SDKs")

## Co aplikacja zapisuje na dysku

### Dane konfiguracyjne (settings)

**Lokalizacja**: `~/Library/Preferences/pl.polskiwhisper.app.plist`
**Format**: macOS UserDefaults plist (binary)
**Zawartość**: Twoje wybrane preferencje:
- Wybrany model Whisper
- Hotkey (np. "Left Option")
- Tryb hotkey (toggle / hold)
- Maksymalny czas nagrywania
- Pozycja okna dyktowania
- Dźwięki start/stop on/off
- Autostart on/off
- Pokaż ikonę w Docku

**Jak usunąć**:
```bash
defaults delete pl.polskiwhisper.app
```

### Vocabulary database

**Lokalizacja**: `~/Library/Application Support/PolskiWhisper/vocabulary.db`
**Format**: SQLite (czytelne przez `sqlite3 vocabulary.db`)
**Zawartość**:
- Custom Words (słowa do "boost" w Whisper)
- Find & Replace rules
- AI Vocabulary (terminy do przyszłego post-processingu - obecnie nieużywane)

**Jak usunąć**:
```bash
rm -rf ~/Library/Application\ Support/PolskiWhisper/
```

### Modele Whisper (cache)

**Lokalizacja**: `~/Library/Caches/PolskiWhisper/whisper-models/`
**Format**: CoreML model packages
**Wielkość**: ~1-3 GB per model
**Można usunąć**: TAK, aplikacja pobierze ponownie przy następnym użyciu

### Audio temp (krótko-żyjące)

**Lokalizacja**: `~/Library/Caches/PolskiWhisper/recording-{timestamp}.wav`
**Kiedy zapisany**: podczas każdego nagrywania (recovery mechanism w razie crash)
**Kiedy usunięty**: **automatycznie po pomyślnym wklejeniu tekstu**
**Co jeśli aplikacja crash**: przy kolejnym starcie aplikacja wykrywa "orphan" pliki i pyta czy je usunąć

**Twoje audio NIGDY nie jest zapisywane permanentnie**, chyba że aplikacja crash przed paste.

### Czego aplikacja **NIE zapisuje**

❌ **Historia transkrypcji** - aplikacja nie ma historii. Każdy dyktat jest natychmiast wklejony i zapomniany
❌ **Logi tekstowe** użytkownika - `os.Logger` zapisuje techniczne logi do Console.app (system-managed), ale **bez treści transkrypcji**
❌ **Kopia transkrypcji** - to co wklejone, nie jest gdzie indziej zapisane
❌ **Cookies, sessions, tokens** - nie ma żadnych
❌ **Browsing history** - nie dotyczy, to nie przeglądarka

## Dane wysyłane do zewnętrznych serwisów

**ŻADNE**.

Wyjątki opisane wyżej (HuggingFace pobieranie modelu) to **standardowe HTTPS GET na publiczne URL-e** - tak samo jak `curl https://huggingface.co/...`. Hugging Face widzi tylko że ktoś z Twojego IP pobrał plik (jak każde inne pobranie pliku). Nic więcej.

## Code audit - jak sprawdzić samemu

Aplikacja jest **open source** na licencji MIT. Możesz przeczytać każdą linię kodu:

```bash
# Sklonuj repo
git clone https://github.com/marcinwerner/polskiwhisper.pl.git
cd polskiwhisper.pl

# Znajdź wszystkie network calls
grep -rn "URLSession\|URLRequest\|HTTPClient" PolskiWhisper/

# Znajdź wszystkie URL-e zahardkodowane
grep -rEn "(https?|wss?)://[^\"]+\"" PolskiWhisper/

# Sprawdź entitlements (uprawnienia)
cat PolskiWhisper/PolskiWhisper.entitlements

# Sprawdź Info.plist (zadeklarowane uprawnienia)
cat PolskiWhisper/Info.plist
```

**Każdy URL w kodzie jest hardcoded** (nie pochodzi z konfiguracji). Jeden endpoint opisany wyżej (HuggingFace - pobieranie modelu Whisper) i nic więcej.

## Network monitoring (dodatkowy audit)

Jeśli chcesz mieć 100% pewność, że aplikacja nie wysyła nic poza zadeklarowanym, użyj:

- **[Little Snitch](https://www.obdev.at/products/littlesnitch/)** - firewall macOS pokazujący każde połączenie
- **[Lulu](https://objective-see.org/products/lulu.html)** - darmowy odpowiednik Little Snitch
- **`tcpdump`** lub **Wireshark** - dla advanced users

Po uruchomieniu PolskiWhisper powinieneś zobaczyć:
- Pierwszy run (onboarding): połączenie do `huggingface.co` (pobranie modelu Whisper)
- Każde dyktowanie: **brak połączeń sieciowych** - wszystko lokalnie
- **Nic innego**

Jeśli zobaczysz inne połączenia - to bug. Zgłoś przez [Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues).

## Uprawnienia macOS

Aplikacja prosi o **dwa** uprawnienia:

### 1. Mikrofon (`NSMicrophoneUsageDescription`)
**Po co**: nagrywanie Twojego głosu do transkrypcji
**Co dzieje się z audio**: jest przetwarzane lokalnie przez Whisper, zapisywane do tymczasowego WAV (kasowany po paste), nigdy nie wysyłane na zewnątrz

### 2. Accessibility (System Settings → Privacy & Security → Accessibility)
**Po co**:
- Monitorowanie hotkey (Left Option) globalnie
- Symulowanie Cmd+V w aktywnej aplikacji (auto-paste)
**Co aplikacja może z tym zrobić**: nasłuchiwać Twoich klawiszy (ALE: nie zapisuje, nie wysyła, używa wyłącznie do detekcji hotkey)

**Audit**: cały kod Accessibility w `Features/Hotkey/ModifierKeyMonitor.swift` i `Features/Dictation/PasteService.swift`. Otwarcie te dwa pliki = audyt zakończony.

## Aktualizacje aplikacji

W wersjach 0.x.y: **brak auto-update**. Pobierasz nową wersję ręcznie z GitHub Releases.

W wersji 1.0+ (planowane): **Sparkle** auto-update.
- Sparkle łączy się tylko z `https://github.com/marcinwerner/polskiwhisper.pl/releases.atom`
- Można wyłączyć w Settings
- **Opt-in** - na pierwszy run pyta czy chcesz włączyć

## Dane dziecka / GDPR / inne regulacje

PolskiWhisper:
- **Nie zbiera żadnych danych** - więc nie ma "danych osobowych" do zarządzania
- **Nie ma konta użytkownika** - brak pojęcia "profil"
- **Nie ma analytics** - brak agregowania użycia
- **Działa offline** - dane nie opuszczają Twojego komputera

GDPR/RODO nie mają zastosowania bo nie ma "data controller" - aplikacja nie ma serwera ani backendu. Twoje dane = Twój komputer.

## Dla audytujących i security researchers

Znalezienie luki bezpieczeństwa, leaku danych, czy network connection nie wymienionego tu = **prośba o zgłoszenie**.

- **Issues**: https://github.com/marcinwerner/polskiwhisper.pl/issues (publiczne)
- **Security Advisories**: https://github.com/marcinwerner/polskiwhisper.pl/security/advisories/new (prywatne, dla embargoed disclosures)

Każde zgłoszenie zostanie potraktowane poważnie i z wdzięcznością. Bug fix w terminie 7 dni dla high-severity issues.

## Zmiany tej polityki

Każda zmiana polityki prywatności będzie zaznaczona w changelog ([CHANGELOG.md](../CHANGELOG.md)) i w datę "Ostatnia aktualizacja" wyżej.

**Filozofia**: ta aplikacja jest "privacy by architecture", nie "privacy by promise". Architecture nie da się zmienić cichaczem - kod jest open source i każdy może audytować.
