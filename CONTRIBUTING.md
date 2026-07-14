# Wkład w PolskiWhisper

Dziękuję za zainteresowanie projektem! PolskiWhisper jest open source na licencji MIT - każdy może kontrybuować.

## Jak pomóc

### Zgłaszanie błędów

Najprostsza i najbardziej pomocna forma kontrybucji.

1. Sprawdź [Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues) czy bug już nie został zgłoszony
2. Jeśli nie - utwórz nowy Issue używając template **"Zgłoś błąd"**
3. Dołącz:
   - Wersję macOS (Apple → Informacje o tym Macu)
   - Model Maca (M1/M2/M3/M4 + RAM)
   - Wersję PolskiWhisper (Settings → O programie)
   - Logi z Console.app (filtruj po `pl.polskiwhisper.app`)
   - Krok-po-kroku jak odtworzyć

### Propozycje funkcji

Mile widziane! Otwórz Issue z template **"Zaproponuj funkcję"**.

**Filtr:** funkcje musi szanować podstawowe zasady projektu:
- ✅ W pełni offline / lokalne
- ✅ Zero telemetrii
- ✅ Brak konta użytkownika ani cloud sync
- ✅ Polski jako language target
- ❌ Cloud sync, online accounts, third-party AI services bez kontroli
- ❌ Telemetria nawet "anonimowa"

### Kod (Pull Requests)

Mniejsze fixy mile widziane. Większe zmiany - **najpierw otwórz Issue** żeby przedyskutować podejście.

#### Setup developerski

```bash
git clone https://github.com/marcinwerner/polskiwhisper.pl.git
cd polskiwhisper.pl
./scripts/setup.sh        # bootstrap (xcodegen + SPM)
open PolskiWhisper.xcodeproj
# Cmd+R w Xcode
```

Pełna dokumentacja: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

#### Konwencje kodu

- **Swift 5.9+** - używaj nowoczesnych features (`@Observable`, `async/await`, strict concurrency)
- **Bez `print()`** - używaj `os.Logger` z istniejących `Log.*` categorii
- **Bez force unwrap `!`** - guard/if-let lub explicit komentarz dlaczego safe
- **Header copyright** w każdym nowym pliku Swift (template w istniejących)
- **Polskie znaki diakrytyczne** (ą, ę, ś, ć, ź, ż, ó, ł, ń) w UI strings i komentarzach
- **`-` zamiast `—`** (krótka pauza zamiast em-dash)
- **Tylko ASCII w identyfikatorach** Swift (compiler ich nie lubi)

#### Architektura

Kluczowe zasady (do wglądu w kodzie):
- **Single responsibility** per service (AudioRecorder, WhisperService, PasteService, etc.)
- **Orchestrator pattern** - DictationEngine koordynuje cały flow
- **State management**: `@Observable` classes + `@MainActor` dla UI
- **Layered structure**: Sources/App, Sources/Features/{Dictation, UI, Onboarding, Hotkey}, Sources/Data, Sources/Supporting

#### Network calls audit

Każdy nowy `URLSession` / `URLRequest` MUSI mieć dokumentację w [docs/PRIVACY.md](docs/PRIVACY.md). Audyt przed PR:

```bash
grep -rn "URLSession\|URLRequest" PolskiWhisper/Sources/
```

Wszystkie URLs muszą być **hardcoded** (nie z konfiguracji). Zmiana network behavior = nowa sekcja w PRIVACY.md.

#### Pull Request checklist

- [ ] Build przechodzi (`xcodebuild build`)
- [ ] Smoke test: tap → mów → tap → tekst się wkleja
- [ ] Polskie znaki w transkrypcji są poprawne
- [ ] Brak nowych warningów w Console.app
- [ ] Header copyright w nowych plikach
- [ ] Zero `print()`, zero force unwraps
- [ ] Dokumentacja zaktualizowana (jeśli zmieniono architekturę)
- [ ] CHANGELOG.md - dodany wpis pod "Unreleased" / kolejna wersja

## Co NIE jest mile widziane

- **Telemetria** - nawet "anonimowa", zero. Aplikacja jest privacy-first by architecture.
- **Cloud sync features** - lokalne narzędzie, świadoma decyzja.
- **Multi-platform port** (iOS, Linux, inne systemy) - macOS native to focus, fork jeśli potrzebujesz.
- **Chmurowe API AI** w stylu OpenAI / Anthropic - aplikacja jest w pełni offline by design.
- **Subtle language changes** poza polski - aplikacja jest dedykowana polskiej społeczności.

## Licencja

Kontrybuując kod do PolskiWhisper, zgadasz się że Twój wkład będzie udostępniony na tej samej licencji co projekt - **MIT**. Bez CLA, bez specjalnych form.

## Kontakt

- **[Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues)** - bug reporty, feature requesty
- **[Discussions](https://github.com/marcinwerner/polskiwhisper.pl/discussions)** - pytania, sugestie, ogólne
- **[Security Advisories](https://github.com/marcinwerner/polskiwhisper.pl/security/advisories/new)** - prywatne disclosure luk

Dzięki za pomoc! 🎤
