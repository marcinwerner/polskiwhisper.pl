# 02 - CONTENT: Źródła treści dla landing page

**Cel**: agent (nowa sesja) ma tu mapę gdzie znaleźć fakty o PolskiWhisper, żeby napisać prawdziwy copy bez wymyślania.

---

## Pliki do przeczytania w repo apki

Lokalizacja repo: `/Users/Marcin/Documents/GitHub/polskiwhisper.pl/`

### MUST READ - core copy source

- **`README.md`** (root) - macOS user-facing, najświeższy stan apki, sekcje Funkcje / Instalacja / Wymagania / FAQ
- **`windows/README.md`** - Windows user-facing, status v0.1.0-preview, parity table z macOS
- **`CHANGELOG.md`** (root) - historia wszystkich releaseów macOS, copy "co nowego"
- **`windows/CHANGELOG.md`** - historia Windows
- **`SECURITY.md`** - polityka bezpieczeństwa, linki do reportowania
- **`CONTRIBUTING.md`** - dla sekcji Community

### NICE TO HAVE - context

- **`ACKNOWLEDGEMENTS.md`** - kogo wspomnieć w credits (whisper.cpp, WhisperKit, OpenAI)
- **`LICENSE`** - MIT, do footer
- **`docs/`** (jeśli istnieje) - dodatkowe dokumenty techniczne
- **`windows/docs/ARCHITECTURE.md`** - dla "Dla developerów" w FAQ
- **`windows/docs/PRIVACY.md`** - dla privacy policy strony

### SKIP

- `**/.internal/**` - gitignored, prywatne notatki / handoffy / decisions
- `**/PolskiWhisper/**`, `**/windows/src/**` - kod źródłowy, nie potrzebny do landing
- `**/.git/**`

## Kluczowe fakty (skrót dla agenta)

Jeśli nie chcesz czytać wszystkich plików, oto destylacja:

### Aplikacja

- **Nazwa**: PolskiWhisper (jedno słowo, "P" duże, "W" duże w środku)
- **Tagline propozycje**: "Pisz głosem. Po polsku.", "Mówisz. Piszesz.", "Polski Whisper offline"
- **Domena**: polskiwhisper.pl
- **Repo**: github.com/marcinwerner/polskiwhisper.pl
- **Licencja**: MIT
- **Cena**: 0 PLN, na zawsze (decyzja w sesji 2026-04-26 - "stabilny hobby project, nie premium polished")
- **Telemetria**: ZERO (audytowalność - kod publiczny)
- **Sklep**: NIE App Store, NIE Microsoft Store - direct download z GitHub

### Wersje (status na 2026-05-09)

| Wersja | Platforma | Status | Pobranie |
|--------|-----------|--------|----------|
| v0.1.5 | macOS | Stable | .dmg z GitHub Releases |
| v0.1.0-preview | Windows | Pre-release (placeholder UI) | .zip 113 MB z GitHub Releases |
| v0.2.0 | Windows | Planowane (~2-4 tyg) | (nie wydane) |
| v1.0.0 | Both | Planowane (~3-6 mies) | (nie wydane) |

**WAŻNE**: zanim wydasz landing, sprawdź aktualny stan releaseów przez GitHub API - może być świeższy. Wersje wyżej są snapshotem.

### Wymagania systemowe

**macOS**:
- macOS 14 Sonoma+ (preferowane Sequoia)
- Apple Silicon (M1/M2/M3) - wymagane dla WhisperKit ANE
- ~2 GB wolnego miejsca (apka + model)
- Mikrofon

**Windows**:
- Windows 10 1809+ lub Windows 11
- ~4 GB wolnego RAM
- ~500 MB miejsca na dysku (apka, model osobno)
- Mikrofon
- Opcjonalnie: GPU z DirectX 12 dla DirectML acceleration

### Funkcje (oba platformy, target v1.0)

- **Hotkey toggle / hold** - skrót klawiszowy do nagrywania (default Right Cmd / Right Ctrl)
- **Esc cancel** - przerwij nagrywanie bez transkrypcji
- **Auto-spacing po `.!?`** - inteligentne dodawanie spacji
- **Hallucination filter** - usuwa typowe halucynacje Whisper ("dziękuję za uwagę", "napisy stworzone przez...")
- **Find & Replace słownik** - drag-drop CSV z personalnymi zamianami (np. "Marcin" → "Marcin Werner")
- **Floating waveform window** - wizualna informacja zwrotna
- **9 dźwięków** start / finish (wybierz lub wycisz)
- **Whisper Turbo default** (1.5 GB) - duży model, najlepsza jakość
- **Auto-update** - one-click update gdy nowa wersja
- **DuplicateAppFinder** - wykrywa zduplikowaną instancję
- **Native notifications** - Toast (Windows) / Notification Center (macOS)
- **Onboarding wizard** - pierwsze uruchomienie
- **Launch at login** - opcjonalne
- **GPU acceleration** - Apple Silicon ANE (mac) / DirectML (win)

### Privacy stance

- **Audio nigdy nie opuszcza komputera** - po setupie pełny offline
- **Brak konta**, **brak rejestracji**, **brak subskrypcji**
- **Brak phone-home** - aplikacja nie pinguje serwerów
- **Update check** - jedyne wyjście do internetu (sprawdza GitHub Releases API), opcjonalne, można wyłączyć
- **Polityka prywatności**: w `windows/docs/PRIVACY.md` (lub root jeśli stworzony)

### Stack techniczny (dla "Dla developerów" FAQ)

**macOS**:
- Swift 5.9+ / SwiftUI / AppKit
- WhisperKit (binding do whisper.cpp z Apple ANE)
- GRDB (SQLite)
- Sparkle 2 (auto-update) - usunięte v0.1.1, teraz manual update flow
- Bundle ID: pl.polskiwhisper.app

**Windows**:
- WinUI 3 / Windows App SDK 1.5
- C# 12 / .NET 8 LTS
- Whisper.net (binding do whisper.cpp z DirectML GPU)
- NAudio (audio capture)
- SharpHook (low-level keyboard hook)
- TextCopy + InputSimulatorPlus (auto-paste)
- Microsoft.Data.Sqlite + JSON (persystencja)
- Serilog (logging)

### Roadmap

| Wersja | Cel | Target | Status |
|--------|-----|--------|--------|
| **v0.1.5** | macOS stable | 2026-05 | ✅ |
| **v0.1.0-preview** | Windows pre-release | 2026-05-09 | ✅ |
| **v0.2.0** | Windows full UI + dyktowanie | 2026-05-23 ~ 2026-06-06 | 🔜 |
| **v0.3.0** | Windows MSI installer + auto-update | 2026-06-23 ~ 2026-07-09 | 🔜 |
| **v1.0.0** | Stable, parity macOS↔Windows | 2026-08 ~ 2026-11 | 🔜 |

### Filozofia

Cytat Marcina (z handoff repo): *"Stabilny hobby project, nie premium polished. Bez Microsoft Store fee, bez telemetrii, bez phone-home. Aplikacja audytowalna - kod publiczny na GitHub."*

To **nie jest startup**, **nie jest SaaS**, **nie planuje skalowania na 1M userów**. To **dobre narzędzie dla siebie i innych**, z kodem otwartym.

## FAQ (gotowe do użycia)

### Czy to naprawdę darmowe?

Tak, na zawsze. Aplikacja jest open-source na licencji MIT. Możesz pobrać, używać, modyfikować, dystrybuować - bez kosztów, bez rejestracji, bez konta.

### Co z prywatnością?

Po pobraniu modelu Whisper (~1.5 GB, jednorazowo) aplikacja działa **w pełni offline**. Twoje audio nigdy nie opuszcza komputera. Nie zbieramy żadnych danych. Nie ma analytics, nie ma telemetrii, nie ma phone-home.

Kod jest publiczny - możesz audytować co dokładnie aplikacja robi.

### Jak dokładne są transkrypcje?

Z domyślnym modelem Whisper Turbo (1.5 GB) dokładność dla polskiego wynosi ~95% słów poprawnych. Lepiej radzi sobie ze studyjną jakością audio (mikrofon blisko ust, mało hałasu w tle).

Aplikacja ma wbudowany **hallucination filter** - usuwa typowe halucynacje Whisper jak "dziękuję za uwagę" czy "napisy stworzone przez społeczność".

### Jakie języki?

Whisper rozumie ~100 języków, ale aplikacja jest **zoptymalizowana pod polski**. Jeśli chcesz angielski - zmień model w ustawieniach (małe modele, lepsze dla EN).

### Czy potrzebuję GPU?

**Mac**: Apple Silicon (M1/M2/M3) jest wymagany - aplikacja używa Apple Neural Engine.

**Windows**: GPU z DirectX 12 jest **opcjonalne** (DirectML acceleration). Bez GPU działa, ale wolniej (CPU fallback).

### Mogę używać w pracy / komercyjnie?

Tak. Licencja MIT pozwala na użycie komercyjne, modyfikację, dystrybucję - z zachowaniem informacji o autorze i licencji.

### Dlaczego nie ma w App Store / Microsoft Store?

Bo nie chcemy płacić $100/rok dla certyfikatów developerskich i $500 dla Microsoft Store. To **hobby project** - dystrybucja przez GitHub Releases jest tańsza i bardziej transparentna (każdy może audytować kod).

### Co jeśli znajdę bug?

Otwórz issue na GitHub: [github.com/marcinwerner/polskiwhisper.pl/issues](https://github.com/marcinwerner/polskiwhisper.pl/issues). Jeśli jesteś z polskiej społeczności, możesz pisać po polsku.

### Skąd model Whisper?

Whisper to open-source model do transkrypcji od OpenAI ([github.com/openai/whisper](https://github.com/openai/whisper)). Aplikacja używa portu **whisper.cpp** (C++) optymalizowanego pod konkretne platformy:
- **macOS**: WhisperKit (Apple Silicon ANE)
- **Windows**: Whisper.net (DirectML GPU)

### Inne rozwiązania też istnieją - co wyróżnia PolskiWhisper?

- **Polski-first** - większość aplikacji do dyktowania (Dragon, Otter, MacWhisper) targetuje EN. Tu polski jest priorytet.
- **Darmowe i open-source** - większość komercyjnych alternatyw kosztuje $5-50/miesiąc lub $300+ jednorazowo.
- **Offline po setupie** - chmurowe rozwiązania (np. Google Speech-to-Text) wysyłają audio na serwery; tu zostaje lokalnie.
- **Auto-paste w dowolnej apce** - niektóre alternatywy działają tylko w swoim oknie; PolskiWhisper wstawia tekst tam gdzie kursor.

## CTA copy (gotowe warianty)

### Pobierz - macOS

- "Pobierz dla macOS"
- "PolskiWhisper.dmg (XX MB)"
- "macOS 14 Sonoma+ na Apple Silicon"

### Pobierz - Windows

- "Pobierz dla Windows (preview)"
- "PolskiWhisper-X.X.X-win-x64.zip (113 MB)"
- "Windows 10 1809+ lub Windows 11"

### Wariant "spróbuj":

- "Pobierz teraz, zacznij oszczędzać czas dziś"
- "5 minut do pobrania, na zawsze szybsze pisanie"

## Komunikaty błędów / edge cases

Jeśli używasz w stronie:

- "Brak najnowszego release-a w GitHub API" → fallback "Pobierz najnowszą wersję" link to releases page
- "WebGPU nie wspierane" → "Spróbuj w Chrome 121+ na desktopie" + fallback do video
- "Mic permission denied" → "Aby użyć demo, zezwól na dostęp do mikrofonu w ustawieniach przeglądarki"

## Hashtags / SEO keywords

**Polish (primary)**:
- `dyktowanie po polsku`
- `transkrypcja głosu polski`
- `Whisper polski offline`
- `darmowe dyktowanie macOS`
- `dyktowanie Windows polski`
- `mowa na tekst po polsku`
- `speech-to-text polski offline`

**English (secondary, dla EN version)**:
- `polish whisper offline`
- `polish speech-to-text macOS`
- `free polish dictation app`
- `polish voice typing`

## Materiały wizualne

### Co JEST dostępne

- Brak custom logo - **GitHub używa default avatar Marcina**
- Brak custom screenshotów do strony - **musisz wygenerować** (zrób screen aplikacji uruchomionej na Mac/Win)

### Co AGENT MOŻE zrobić

- **Wygenerować typograficzne logo** (SVG, "PolskiWhisper" w fancy fontu, opcjonalnie z falą dźwiękową)
- **Wygenerować mockupy** macOS i Windows używając Figma / Photoshop alternatives, lub stockowe mockupy (np. cleanmock.com, mockup.photos)
- **Animować placeholder waveform** (canvas / SVG) zamiast pokazywać prawdziwą falę
- **Pre-recorded video** z prawdziwego użycia - jeśli Marcin go nagra (zostaw placeholder w kodzie, link który można podmienić)

### Brand assets do wygenerowania w sesji

- Favicon (multi-size, ICO + PNG)
- Apple touch icon
- OG image (1200×630, dynamic z @vercel/og lub static SVG)
- Hero illustration (waveform + tekst)
- Section dividers (subtelne)

## Linki zewnętrzne (do użycia)

- **GitHub repo**: https://github.com/marcinwerner/polskiwhisper.pl
- **Issues**: https://github.com/marcinwerner/polskiwhisper.pl/issues
- **Releases**: https://github.com/marcinwerner/polskiwhisper.pl/releases
- **Latest macOS release**: https://github.com/marcinwerner/polskiwhisper.pl/releases/latest
- **Latest Windows release**: https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/win-v0.1.0-preview
- **Email kontaktowy**: kontakt@marcinwerner.com
- **Whisper od OpenAI**: https://github.com/openai/whisper
- **whisper.cpp**: https://github.com/ggerganov/whisper.cpp
- **WhisperKit**: https://github.com/argmaxinc/WhisperKit
- **Whisper.net**: https://github.com/sandrohanea/whisper.net
- **Vercel**: https://vercel.com (jeśli badge "Powered by Vercel")
